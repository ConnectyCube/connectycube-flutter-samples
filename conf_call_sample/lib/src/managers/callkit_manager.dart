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
  static String tag = "CallKitManager";

  static CallKitManager _getInstance() {
    return _instance ??= CallKitManager._internal();
  }

  factory CallKitManager() => _getInstance();

  CallKitManager._internal();

  late Function(CallEvent callEvent) onCallAccepted;
  late Function(CallEvent callEvent) onCallEnded;
  late Function(bool mute, String uuid) onMuteCall;

  init({
    required Function(CallEvent callEvent) onCallAccepted,
    required Function(CallEvent callEvent) onCallEnded,
    required Function(bool mute, String uuid) onMuteCall,
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
              sessionId: callData[paramSessionId].toString(),
              callType: int.parse(callData[paramCallType].toString()),
              callerId: int.parse(callData[paramCallerId].toString()),
              callerName: callData[paramCallerName] as String,
              opponentsIds: (callData[paramCallOpponents] as String)
                  .split(',')
                  .map(int.parse)
                  .toSet(),
              userInfo: callData[paramUserInfo] != null
                  ? Map<String, String>.from(
                      jsonDecode(callData[paramUserInfo]))
                  : null,
            );
          });
        }
        return null;
      });
    });
  }
}

@pragma('vm:entry-point')
Future<void> onCallRejectedWhenTerminated(CallEvent callEvent) async {
  log('[PushNotificationsManager][onCallRejectedWhenTerminated] callEvent: $callEvent');

  var meetingId = callEvent.userInfo?[paramMeetingId];
  if (meetingId == null) return;

  initConnectycubeContextLess();

  var callMsgList =
      buildCallMessages(callEvent.sessionId, meetingId, [callEvent.callerId]);
  for (var callMsg in callMsgList) {
    callMsg.properties[signalTypeRejectCall] = '1';
    callMsg.properties[paramBusy] = 'false';
  }

  for (var msg in callMsgList) {
    sendSystemMessage(msg.recipientId!, msg.properties);
  }

  var sendRejectCallMessage = callMsgList.map((msg) {
    return sendSystemMessage(msg.recipientId!, msg.properties);
  }).toList();

  var sendPushAboutReject = sendPushAboutRejectFromKilledState({
    paramCallType: callEvent.callType,
    paramSessionId: callEvent.sessionId,
    paramCallerId: callEvent.callerId,
    paramCallerName: callEvent.callerName,
    paramCallOpponents: callEvent.opponentsIds.join(','),
    paramUserInfo: {paramMeetingId: meetingId},
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
  params.parameters[paramMessage] = "Reject call";
  params.parameters[paramSignalType] = signalTypeRejectCall;

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
  params.parameters[paramSessionId] = callId;
  params.parameters[paramMessage] = 'End call';
  params.parameters[paramSignalType] = signalTypeEndCall;

  params.notificationType = NotificationType.PUSH;
  params.environment =
      kReleaseMode ? CubeEnvironment.PRODUCTION : CubeEnvironment.DEVELOPMENT;
  params.usersIds = participants;

  return createEvent(params.getEventForRequest());
}
