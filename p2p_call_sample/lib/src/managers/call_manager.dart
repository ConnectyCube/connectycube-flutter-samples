import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:universal_io/io.dart';

import 'package:connectycube_flutter_call_kit/connectycube_flutter_call_kit.dart';
import 'package:connectycube_sdk/connectycube_sdk.dart';

import 'call_kit_manager.dart';
import '../conversation_screen.dart';
import '../incoming_call_screen.dart';
import '../utils/configs.dart';
import '../utils/consts.dart';

class CallManager {
  static String TAG = "CallManager";

  // collect pending calls in case when it was accepted/ended before establish chat connection
  Map<String?, String> _callsMap = {};

  static CallManager get instance => _getInstance();
  static CallManager? _instance;

  static CallManager _getInstance() {
    return _instance ??= CallManager._internal();
  }

  factory CallManager() => _getInstance();

  CallManager._internal();

  P2PClient? _callClient;
  P2PSession? _currentCall;
  BuildContext? context;

  init(BuildContext context) {
    this.context = context;

    _initCustomMediaConfigs();

    if (CubeChatConnection.instance.isAuthenticated()) {
      _initCalls();
    } else {
      _initChatConnectionStateListener();
    }

    _initCallKit();
  }

  destroy() {
    P2PClient.instance.destroy();
    _callsMap.clear();
  }

  void _initCustomMediaConfigs() {
    RTCMediaConfig mediaConfig = RTCMediaConfig.instance;
    mediaConfig.minHeight = 720;
    mediaConfig.minWidth = 1280;
    mediaConfig.minFrameRate = 30;

    RTCConfig.instance.statsReportsInterval = 200;
  }

  void _initCalls() {
    if (_callClient == null) {
      _callClient = P2PClient.instance;

      _callClient!.init();
    }

    _callClient!.onReceiveNewSession = (callSession) async {
      if (_currentCall != null &&
          _currentCall!.sessionId != callSession.sessionId) {
        callSession.reject();
        return;
      }
      _currentCall = callSession;

      var callState = await _getCallState(_currentCall!.sessionId);

      if (callState == CallState.REJECTED) {
        reject(_currentCall!.sessionId);
      } else if (callState == CallState.ACCEPTED) {
        acceptCall(_currentCall!.sessionId);
      } else if (callState == CallState.UNKNOWN) {
        // ConnectycubeFlutterCallKit.setCallState(sessionId: _currentCall.sessionId, callState: CallState.PENDING);
        // _showIncomingCallScreen(_currentCall);
        if (Platform.isWindows || Platform.isMacOS || kIsWeb) {
          _showIncomingCallScreen(_currentCall!);
        }
      }
    };

    _callClient!.onSessionClosed = (callSession) {
      if (_currentCall != null &&
          _currentCall!.sessionId == callSession.sessionId) {
        _currentCall = null;
        CallKitManager.instance.processCallFinished(callSession.sessionId);
      }
    };
  }

  void startNewCall(
      BuildContext context, int callType, Set<int> opponents) async {
    if (opponents.isEmpty) return;

    P2PSession callSession =
        _callClient!.createCallSession(callType, opponents);
    _currentCall = callSession;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ConversationCallScreen(callSession, false),
      ),
    );

    _sendStartCallSignalForOffliners(_currentCall!);
  }

  void _showIncomingCallScreen(P2PSession callSession) {
    if (context != null) {
      Navigator.push(
        context!,
        MaterialPageRoute(
          builder: (context) => IncomingCallScreen(callSession),
        ),
      );
    }
  }

  void _savePendingCall(sessionId) {
    _callsMap[sessionId] = CallState.PENDING;
  }

  void acceptCall(String sessionId) {
    ConnectycubeFlutterCallKit.setOnLockScreenVisibility(isVisible: true);
    if (_currentCall != null) {
      if (context != null) {
        Navigator.pushReplacement(
          context!,
          MaterialPageRoute(
            builder: (context) => ConversationCallScreen(_currentCall!, true),
          ),
        );
      }
    } else {
      _callsMap[sessionId] = CallState.ACCEPTED;
    }
  }

  void reject(String sessionId) {
    if (_currentCall != null) {
      CallKitManager.instance.processCallFinished(_currentCall!.sessionId);
      _currentCall!.reject();
    } else {
      _callsMap[sessionId] = CallState.REJECTED;
    }
  }

  void hungUp() {
    if (_currentCall != null) {
      CallKitManager.instance.processCallFinished(_currentCall!.sessionId);
      _sendEndCallSignalForOffliners(_currentCall!);
      _currentCall!.hungUp();
    }
  }

  CreateEventParams _getCallEventParameters(P2PSession currentCall) {
    String? callerName = users
        .where((cubeUser) => cubeUser.id == currentCall.callerId)
        .first
        .fullName;

    CreateEventParams params = CreateEventParams();
    params.parameters = {
      'message':
          "Incoming ${currentCall.callType == CallType.VIDEO_CALL ? "Video" : "Audio"} call",
      PARAM_CALL_TYPE: currentCall.callType,
      PARAM_SESSION_ID: currentCall.sessionId,
      PARAM_CALLER_ID: currentCall.callerId,
      PARAM_CALLER_NAME: callerName,
      PARAM_CALL_OPPONENTS: currentCall.opponentsIds.join(','),
    };

    params.notificationType = NotificationType.PUSH;
    params.environment = CubeEnvironment
        .DEVELOPMENT; // TODO for sample we use DEVELOPMENT environment
    // bool isProduction = bool.fromEnvironment('dart.vm.product');
    // params.environment =
    //     isProduction ? CubeEnvironment.PRODUCTION : CubeEnvironment.DEVELOPMENT;
    params.usersIds = currentCall.opponentsIds.toList();

    return params;
  }

  void _sendStartCallSignalForOffliners(P2PSession currentCall) {
    CreateEventParams params = _getCallEventParameters(currentCall);
    params.parameters[PARAM_SIGNAL_TYPE] = SIGNAL_TYPE_START_CALL;
    params.parameters[PARAM_IOS_VOIP] = 1;

    createEvent(params.getEventForRequest()).then((cubeEvent) {
      log("Event for offliners created: $cubeEvent");
    }).catchError((error) {
      log("ERROR occurs during create event");
    });
  }

  void _sendEndCallSignalForOffliners(P2PSession currentCall) {
    CubeUser? currentUser = CubeChatConnection.instance.currentUser;
    if (currentUser == null || currentUser.id != currentCall.callerId) return;

    CreateEventParams params = _getCallEventParameters(currentCall);
    params.parameters[PARAM_SIGNAL_TYPE] = SIGNAL_TYPE_END_CALL;

    createEvent(params.getEventForRequest()).then((cubeEvent) {
      log("Event for offliners created");
    }).catchError((error) {
      log("ERROR occurs during create event");
    });
  }

  void _initCallKit() {
    CallKitManager.instance.init(
      onCallAccepted: (uuid) {
        acceptCall(uuid);
      },
      onCallEnded: (uuid) {
        hungUp();
      },
      onMuteCall: (mute, uuid) {
        _currentCall?.setMicrophoneMute(mute);
      },
    );
  }

  void _initChatConnectionStateListener() {
    CubeChatConnection.instance.connectionStateStream.listen((state) {
      if (CubeChatConnectionState.Ready == state) {
        _initCalls();
      }
    });
  }

  Future<String> _getCallState(String sessionId) async {
    if (Platform.isAndroid) {
      return ConnectycubeFlutterCallKit.getCallState(sessionId: sessionId);
    } else if (Platform.isIOS) {
      if (_callsMap.containsKey(sessionId)) {
        return Future.value(_callsMap[sessionId]);
      }
    }

    return Future.value(CallState.UNKNOWN);
  }
}
