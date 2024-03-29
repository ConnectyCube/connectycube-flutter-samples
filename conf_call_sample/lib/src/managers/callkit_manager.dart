import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:universal_io/io.dart';

import 'package:connectycube_flutter_call_kit/connectycube_flutter_call_kit.dart';
import 'package:connectycube_sdk/connectycube_sdk.dart';

import '../../main.dart';
import '../utils/consts.dart';
import 'call_manager.dart';

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
      color: '#07711e',
      // ringtone:
      // Platform.isAndroid ? 'custom_ringtone' : 'Resources/ringtones/custom_ringtone.caf'
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

  Future<void> sendEndCallPushNotification(
      String callId, List<int> participants) async {
    if (Platform.isAndroid || Platform.isIOS) {
      sendPushAboutEndingCall(callId, participants);
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
              sessionId: callData[PARAM_SESSION_ID].toString(),
              callType: int.parse(callData[PARAM_CALL_TYPE].toString()),
              callerId: int.parse(callData[PARAM_CALLER_ID].toString()),
              callerName: callData[PARAM_CALLER_NAME] as String,
              opponentsIds: (callData[PARAM_CALL_OPPONENTS] as String)
                  .split(',')
                  .map(int.parse)
                  .toSet(),
              userInfo: callData[PARAM_USER_INFO] != null
                  ? Map<String, String>.from(
                      jsonDecode(callData[PARAM_USER_INFO]))
                  : null,
            );
            ;
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

  var meetingId = callEvent.userInfo?[PARAM_MEETING_ID];
  if (meetingId == null) return;

  initConnectycubeContextLess();

  var callMsgList =
      buildCallMessages(callEvent.sessionId, meetingId, [callEvent.callerId]);
  callMsgList.forEach((callMsg) {
    callMsg.properties[SIGNAL_TYPE_REJECT_CALL] = '1';
    callMsg.properties[PARAM_BUSY] = 'false';
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
    PARAM_USER_INFO: {PARAM_MEETING_ID: meetingId},
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
  params.parameters[PARAM_MESSAGE] = "Reject call";
  params.parameters[PARAM_SIGNAL_TYPE] = SIGNAL_TYPE_REJECT_CALL;

  params.notificationType = NotificationType.PUSH;
  params.environment =
      kReleaseMode ? CubeEnvironment.PRODUCTION : CubeEnvironment.DEVELOPMENT;
  params.usersIds = [callerId];

  return createEvent(params.getEventForRequest());
}

Future<void> sendPushAboutEndingCall(
  String callId,
  List<int> participants,
) {
  CreateEventParams params = CreateEventParams();
  params.parameters[PARAM_SESSION_ID] = callId;
  params.parameters[PARAM_MESSAGE] = 'End call';
  params.parameters[PARAM_SIGNAL_TYPE] = SIGNAL_TYPE_END_CALL;

  params.notificationType = NotificationType.PUSH;
  params.environment =
      kReleaseMode ? CubeEnvironment.PRODUCTION : CubeEnvironment.DEVELOPMENT;
  params.usersIds = participants;

  return createEvent(params.getEventForRequest());
}
