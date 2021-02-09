import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_call_kit/flutter_call_kit.dart';

import 'package:connectycube_sdk/connectycube_sdk.dart';

import 'call_kit_manager.dart';
import '../conversation_screen.dart';
import '../incoming_call_screen.dart';
import '../utils/configs.dart';

class CallManager {
  static String TAG = "CallManager";

  // collect pending calls in case when it was accepted/ended before establish chat connection
  List<String> _pendingAccept = [];
  List<String> _pendingEnd = [];

  static CallManager get instance => _getInstance();
  static CallManager _instance;

  static CallManager _getInstance() {
    if (_instance == null) {
      _instance = CallManager._internal();
    }
    return _instance;
  }

  factory CallManager() => _getInstance();

  CallManager._internal();

  P2PClient _callClient;
  P2PSession _currentCall;

  BuildContext context;

  init(BuildContext context, {CubeUser cubeUser}) {
    this.context = context;
    _initCustomMediaConfigs();
    _initCalls();
    _initCallKit();
  }

  destroy() {
    P2PClient.instance.destroy();
  }

  void _initCustomMediaConfigs() {
    RTCMediaConfig mediaConfig = RTCMediaConfig.instance;
    mediaConfig.minHeight = 720;
    mediaConfig.minWidth = 1280;
    mediaConfig.minFrameRate = 30;
  }

  void _initCalls() {
    _callClient = P2PClient.instance;

    _callClient.init();

    _callClient.onReceiveNewSession = (callSession) {
      log("[onReceiveNewSession] uuid: ${callSession.sessionId}",
          CallManager.TAG);
      if (_currentCall != null &&
          _currentCall.sessionId != callSession.sessionId) {
        callSession.reject();
        return;
      }
      log("[onReceiveNewSession] save as current, uuid: ${callSession.sessionId}",
          CallManager.TAG);
      _currentCall = callSession;

      if (_pendingEnd.contains(_currentCall.sessionId)) {
        _currentCall.reject();
        _pendingEnd.remove(_currentCall.sessionId);
      } else if (_pendingAccept.contains(_currentCall.sessionId)) {
        acceptCall(_currentCall.sessionId);
        _pendingAccept.remove(_currentCall.sessionId);
      } else if (Platform.isAndroid) { // for iOS will be shown CallKit's notification
        _showIncomingCallScreen(_currentCall);
      }
    };

    _callClient.onSessionClosed = (callSession) {
      log("[onSessionClosed] uuid: ${callSession.sessionId}", CallManager.TAG);
      if (_currentCall != null &&
          _currentCall.sessionId == callSession.sessionId) {
        _currentCall = null;
        CallKitManager.instance.reportEndCallWithUUID(
            callSession.sessionId, EndReason.remoteEnded);
      }
    };
  }

  void startNewCall(BuildContext context, int callType, Set<int> opponents) {
    if (opponents.isEmpty) return;

    P2PSession callSession = _callClient.createCallSession(callType, opponents);
    _currentCall = callSession;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ConversationCallScreen(callSession, false),
      ),
    );

    _sendNotificationForOffliners(_currentCall);
  }

  void _showIncomingCallScreen(P2PSession callSession) {
    log("[_showIncomingCallScreen] uuid: ${callSession.sessionId}",
        CallManager.TAG);
    if (context != null) {
      log("[_showIncomingCallScreen] context != null", CallManager.TAG);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => IncomingCallScreen(callSession),
        ),
      );
    }
  }

  void acceptCall(String sessionId) {
    log("[acceptCall]", CallManager.TAG);
    if (_currentCall != null) {
      log("[acceptCall] _currentCall != null", CallManager.TAG);
      if (context != null) {
        log("[acceptCall] context != null", CallManager.TAG);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ConversationCallScreen(_currentCall, true),
          ),
        );
      }
    } else {
      _pendingAccept.add(sessionId);
    }
  }

  void reject(String sessionId) {
    log("[reject]", CallManager.TAG);

    if (_currentCall != null) {
      log("[reject] _currentCall != null", CallManager.TAG);
      CallKitManager.instance.rejectCall(_currentCall.sessionId);
      _currentCall.reject();
    } else {
      _pendingAccept.remove(sessionId);
      _pendingEnd.add(sessionId);
    }
  }

  void hungUp() {
    log("[hungUp]", CallManager.TAG);
    if (_currentCall != null) {
      log("[hungUp] _currentCall != null", CallManager.TAG);
      CallKitManager.instance.endCall(_currentCall.sessionId);
      _currentCall.hungUp();
    }
  }

  void _sendNotificationForOffliners(P2PSession currentCall) {
    bool isProduction = bool.fromEnvironment('dart.vm.product');
    String callerName = users
        .where((cubeUser) => cubeUser.id == currentCall.callerId)
        .first
        .fullName;

    CreateEventParams params = CreateEventParams();
    params.parameters = {
      'message':
          "Incoming ${currentCall.callType == CallType.VIDEO_CALL ? "Video" : "Audio"} call",
      'call_type': currentCall.callType,
      'session_id': currentCall.sessionId,
      'caller_id': currentCall.callerId,
      'caller_name': callerName,
      'ios_voip': 1,
    };

    params.notificationType = NotificationType.PUSH;
    params.environment = CubeEnvironment.DEVELOPMENT;
    // params.environment =
    //     isProduction ? CubeEnvironment.PRODUCTION : CubeEnvironment.DEVELOPMENT;
    params.usersIds = currentCall.opponentsIds.toList();

    createEvent(params.getEventForRequest()).then((cubeEvent) {
      log("Event for offliners created");
    }).catchError((error) {
      log("ERROR occurs during create event");
    });
  }

  void _initCallKit() {
    CallKitManager.instance.init(
      onCallAccepted: (uuid) {
        log("[onCallAccepted] uuid: $uuid", CallManager.TAG);
        acceptCall(uuid);
      },
      onCallEnded: (uuid) {
        log("[onCallEnded] uuid: $uuid", CallManager.TAG);
        hungUp();
      },
      onNewCallShown: (error, uuid, handle, callerName, fromPushKit) {
        log("[onNewCallShown] uuid: $uuid, error: $error", CallManager.TAG);
      },
      onMuteCall: (mute, uuid) {
        log("[onMuteCall] mute: $mute, uuid: $uuid", CallManager.TAG);
        _currentCall?.setMicrophoneMute(mute);
      },
    );
  }
}
