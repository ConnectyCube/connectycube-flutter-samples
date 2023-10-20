import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:universal_io/io.dart';

import 'package:connectycube_flutter_call_kit/connectycube_flutter_call_kit.dart';
import 'package:connectycube_sdk/connectycube_sdk.dart';

import '../../main.dart';
import 'call_manager.dart';
import 'consts.dart';

class CallKitManager {
  static CallKitManager get instance => _getInstance();
  static CallKitManager? _instance;
  static String TAG = "CallKitManager";

  static CallKitManager _getInstance() {
    return _instance ??= CallKitManager._internal();
  }

  factory CallKitManager() => _getInstance();

  CallKitManager._internal();

  late Function(CallEvent callEvent) onCallAccepted;
  late Function(CallEvent CallEvent) onCallEnded;
  late Function(bool mute, String uuid) onMuteCall;

  init({
    required onCallAccepted(CallEvent callEvent),
    required onCallEnded(CallEvent callEvent),
    required onMuteCall(bool mute, String uuid),
  }) {
    this.onCallAccepted = onCallAccepted;
    this.onCallEnded = onCallEnded;
    this.onMuteCall = onMuteCall;

    ConnectycubeFlutterCallKit.instance.init(
      onCallAccepted: _onCallAccepted,
      onCallRejected: _onCallRejected,
      icon: Platform.isAndroid ? 'default_avatar' : 'CallKitIcon',
        notificationIcon: 'ic_notification',
        color: '#07711e',
        ringtone:
        Platform.isAndroid ? 'custom_ringtone' : 'Resources/ringtones/custom_ringtone.caf'
    );
    ConnectycubeFlutterCallKit.onCallRejectedWhenTerminated =
        onCallRejectedWhenTerminated;

    if (Platform.isIOS) {
      ConnectycubeFlutterCallKit.onCallMuted = _onCallMuted;
    }
  }

  Future<void> processCallFinished(String uuid) async {
    if (Platform.isAndroid || Platform.isIOS) {
      ConnectycubeFlutterCallKit.reportCallEnded(sessionId: uuid);
      ConnectycubeFlutterCallKit.setOnLockScreenVisibility(isVisible: false);
      ConnectycubeFlutterCallKit.clearCallData(sessionId: uuid);
    }
  }

  Future<void> processCallStarted(String uuid) async {
    if (Platform.isAndroid || Platform.isIOS) {
      ConnectycubeFlutterCallKit.reportCallAccepted(sessionId: uuid);
      ConnectycubeFlutterCallKit.setOnLockScreenVisibility(isVisible: true);
    }
  }

  Future<void> _onCallMuted(bool mute, String callId) async {
    onMuteCall.call(mute, callId);
  }

  Future<void> _onCallAccepted(CallEvent callEvent) async {
    onCallAccepted.call(callEvent);
  }

  Future<void> _onCallRejected(CallEvent callEvent) async {
    onCallEnded.call(callEvent);
  }

  void muteMic(String callId, bool mute) {
    ConnectycubeFlutterCallKit.reportCallMuted(sessionId: callId, muted: mute);
  }

  Future<CallEvent?> getCallToStart() {
    return ConnectycubeFlutterCallKit.getLastCallId().then((lastCallId) {
      if (lastCallId == null) {
        return null;
      }

      return ConnectycubeFlutterCallKit.getCallState(sessionId: lastCallId)
          .then((state) {
        if (state == CallState.ACCEPTED) {
          return ConnectycubeFlutterCallKit.getCallData(sessionId: lastCallId)
              .then((callData) {
            if (callData == null) return null;

            return CallEvent(
              sessionId: callData['session_id'].toString(),
              callType: int.parse(callData['call_type'].toString()),
              callerId: int.parse(callData['caller_id'].toString()),
              callerName: callData['caller_name'] as String,
              opponentsIds:
              (callData['call_opponents'] as String).split(',').map(int.parse).toSet(),
              userInfo: callData['user_info'] != null
                  ? Map<String, String>.from(jsonDecode(callData['user_info']))
                  : null,
            );;
          });
        }
        return null;
      });
    });
  }
}

@pragma('vm:entry-point')
Future<void> onCallRejectedWhenTerminated(CallEvent callEvent) async {
  print(
      '[PushNotificationsManager][onCallRejectedWhenTerminated] callEvent: $callEvent');

  var meetingId = callEvent.userInfo?['meetingId'];
  if (meetingId == null) return;

  initConnectycubeContextLess();

  var callMsgList =
      buildCallMessages(callEvent.sessionId, meetingId, [callEvent.callerId]);
  callMsgList.forEach((callMsg) {
    callMsg.properties['callRejected'] = '1';
    callMsg.properties['busy'] = 'false';
  });

  callMsgList
      .forEach((msg) => sendSystemMessage(msg.recipientId!, msg.properties));

  var sendRejectCallMessage = callMsgList.map((msg) {
    return sendSystemMessage(msg.recipientId!, msg.properties);
  }).toList();

  var sendPushAboutReject = sendPushAboutRejectFromKilledState({
    PARAM_CALL_TYPE: callEvent.callType,
    PARAM_SESSION_ID: callEvent.sessionId,
    PARAM_CALLER_ID: callEvent.callerId,
    PARAM_CALLER_NAME: callEvent.callerName,
    PARAM_CALL_OPPONENTS: callEvent.opponentsIds.join(','),
    PARAM_USER_INFO: {'meetingId': meetingId},
  }, callEvent.callerId);

  return Future.wait([...sendRejectCallMessage, sendPushAboutReject])
      .then((result) {
    return Future.value();
  });
}

Future<void> sendPushAboutRejectFromKilledState(
  Map<String, dynamic> parameters,
  int callerId,
) {
  CreateEventParams params = CreateEventParams();
  params.parameters = parameters;
  params.parameters['message'] = "Reject call";
  params.parameters[PARAM_SIGNAL_TYPE] = SIGNAL_TYPE_REJECT_CALL;

  params.notificationType = NotificationType.PUSH;
  params.environment =
      kReleaseMode ? CubeEnvironment.PRODUCTION : CubeEnvironment.DEVELOPMENT;
  params.usersIds = [callerId];

  return createEvent(params.getEventForRequest());
}
