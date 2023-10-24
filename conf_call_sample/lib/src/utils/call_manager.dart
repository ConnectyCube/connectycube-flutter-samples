import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:universal_io/io.dart';
import 'package:uuid/uuid.dart';

import 'package:connectycube_flutter_call_kit/connectycube_flutter_call_kit.dart';
import 'package:connectycube_sdk/connectycube_sdk.dart';

import '../conversation_call_screen.dart';
import 'callkit_manager.dart';
import 'consts.dart';
import 'pref_util.dart';
import 'push_notifications_manager.dart';

const NO_ANSWER_TIMER_INTERVAL = 60;

class CallManager {
  static final String TAG = 'CallManager';
  SystemMessagesManager? _systemMessagesManager;
  NewCallCallback? onReceiveNewCall;
  CloseCall? onCloseCall;
  RejectCallCallback? onReceiveRejectCall;
  CallActionCallback? onCallAccepted;
  CallActionCallback? onCallRejected;
  MuteCallCallback? onCallMuted;
  UserNotAnswerCallback? onUserNotAnswerCallback;
  String? _meetingId;
  List<int>? _participantIds;
  int? _initiatorId;
  Map<String, String> _meetingsCalls = {};
  InternalCallState? _currentCallState;

  var _answerUserTimers = Map<int, Timer>();

  late BuildContext context;

  CallManager._privateConstructor() {
    RTCConfig.instance.statsReportsInterval = 200;
  }

  static final CallManager _instance = CallManager._privateConstructor();

  static CallManager get instance => _instance;

  init(BuildContext context) {
    log('[init]', TAG);
    this.context = context;
    if (Platform.isAndroid || Platform.isIOS) {
      PushNotificationsManager.instance.init();
      CallKitManager.instance.init(
          onCallAccepted: _onCallAccepted,
          onCallEnded: _onCallEnded,
          onMuteCall: _onMuteCall);
    }
    _initSignalingListener();
  }

  parseCallMessage(CubeMessage cubeMessage) {
    log("parseCallMessage cubeMessage= $cubeMessage");

    if (cubeMessage.senderId == CubeChatConnection.instance.currentUser?.id)
      return;

    final properties = cubeMessage.properties;
    var meetingId = properties["meetingId"];
    var callId = properties["callId"]!;

    if (properties.containsKey("callStart")) {
      var participantIds = properties["participantIds"]!
          .split(',')
          .map((id) => int.parse(id))
          .toList();
      var callType = int.tryParse(properties["callType"]?.toString() ?? '') ??
          CallType.VIDEO_CALL;
      var callName = properties["callName"] ??
          cubeMessage.senderId?.toString() ??
          'Unknown Caller';
      if (_meetingId == null) {
        _currentCallState = InternalCallState.NEW;
        onReceiveNewCall?.call(callId, meetingId!, cubeMessage.senderId!,
            participantIds, callType, callName);
      }
    } else if (properties.containsKey("callAccepted")) {
      if (_meetingId == meetingId) {
        _clearNoAnswerTimers(id: cubeMessage.senderId!);
      }
    } else if (properties.containsKey("callRejected")) {
      bool isBusy = properties["busy"] == 'true';
      if (_meetingId == meetingId) {
        onReceiveRejectCall?.call(meetingId!, cubeMessage.senderId!, isBusy);

        handleRejectCall(cubeMessage.senderId!, isBusy);
      }
    } else if (properties.containsKey("callEnd")) {
      processCallFinishedByParticipant(
          cubeMessage.senderId!, callId, meetingId!);
    }
  }

  startNewOutgoingCall(String meetingId, List<int> participantIds,
      int currentUserId, int callType, String callName) {
    _initiatorId = currentUserId;
    _participantIds = participantIds;
    _meetingId = meetingId;
    _meetingsCalls[_meetingId!] = Uuid().v4();
    _currentCallState = InternalCallState.NEW;
    sendCallMessage(_meetingsCalls[_meetingId!]!, meetingId, participantIds,
        callType, callName);
    startNoAnswerTimers(participantIds);
    _sendStartCallSignalForOffliners(_meetingsCalls[_meetingId!]!, meetingId,
        callType, callName, currentUserId, participantIds.toSet());
  }

  reject(String callId, String meetingId, bool isBusy, int initiatorId,
      bool fromCallKit) {
    _currentCallState = InternalCallState.REJECTED;
    sendRejectMessage(callId, meetingId, isBusy, initiatorId);

    if (!fromCallKit) {
      CallKitManager.instance.processCallFinished(callId);
    }

    _clearCallData();
  }

  stopCall(CubeUser currentUser) {
    currentCallState = InternalCallState.FINISHED;

    _clearNoAnswerTimers();

    if (_meetingId == null) return;

    sendEndCallMessage(
        _meetingsCalls[_meetingId!]!, _meetingId!, _participantIds!);
    if (_initiatorId == currentUser.id) {
      CallKitManager.instance.sendEndCallPushNotification(
          _meetingsCalls[_meetingId!]!, _participantIds!);
    }
    CallKitManager.instance.processCallFinished(_meetingsCalls[_meetingId!]!);
    _clearCallData();
  }

  processCallFinishedByParticipant(
      int userId, String callId, String meetingId) {
    if (_meetingId == null) {
      _currentCallState = InternalCallState.FINISHED;

      onCloseCall?.call();
      CallKitManager.instance.processCallFinished(callId);
    } else if (_meetingId == meetingId) {
      _clearCall(userId);
    }
  }

  sendCallMessage(String callId, String meetingId, List<int> participantIds,
      int callType, String callName) {
    List<CubeMessage> callMsgList =
        buildCallMessages(callId, meetingId, participantIds);
    callMsgList.forEach((callMsg) {
      callMsg.properties['callStart'] = '1';
      callMsg.properties['participantIds'] = participantIds.join(',');
      callMsg.properties['callType'] = callType.toString();
      callMsg.properties['callName'] = callName;
    });
    callMsgList
        .forEach((msg) => sendSystemMessage(msg.recipientId!, msg.properties));
  }

  sendAcceptMessage(String callId, String meetingId, int participantId) {
    List<CubeMessage> callMsgList =
        buildCallMessages(callId, meetingId, [participantId]);
    callMsgList.forEach((callMsg) {
      callMsg.properties['callAccepted'] = '1';
    });
    callMsgList
        .forEach((msg) => sendSystemMessage(msg.recipientId!, msg.properties));
  }

  sendRejectMessage(
      String callId, String meetingId, bool isBusy, int participantId) {
    List<CubeMessage> callMsgList =
        buildCallMessages(callId, meetingId, [participantId]);
    callMsgList.forEach((callMsg) {
      callMsg.properties['callRejected'] = '1';
      callMsg.properties['busy'] = isBusy.toString();
    });
    callMsgList
        .forEach((msg) => sendSystemMessage(msg.recipientId!, msg.properties));
  }

  sendEndCallMessage(
      String callId, String meetingId, List<int> participantIds) {
    List<CubeMessage> callMsgList =
        buildCallMessages(callId, meetingId, participantIds);
    callMsgList.forEach((callMsg) {
      callMsg.properties['callEnd'] = '1';
    });
    callMsgList
        .forEach((msg) => sendSystemMessage(msg.recipientId!, msg.properties));
  }

  muteMic(String meetingId, bool mute) {
    CallKitManager.instance.muteMic(_meetingsCalls[meetingId]!, mute);
  }

  handleAcceptCall(int participantId) {
    _clearNoAnswerTimers(id: participantId);
  }

  handleRejectCall(int participantId, isBusy) {
    _clearNoAnswerTimers(id: participantId);
    _clearCall(participantId);
  }

  startNoAnswerTimers(participantIds) {
    participantIds.forEach((userId) => {
          _answerUserTimers[userId] = Timer(
              Duration(seconds: NO_ANSWER_TIMER_INTERVAL),
              () => noUserAnswer(userId))
        });
  }

  noUserAnswer(int participantId) {
    onUserNotAnswerCallback?.call(participantId);
    _clearNoAnswerTimers(id: participantId);
    sendEndCallMessage(
        _meetingsCalls[_meetingId!]!, _meetingId!, [participantId]);
    _clearCall(participantId);
  }

  _clearNoAnswerTimers({int id = 0}) {
    if (id != 0) {
      _answerUserTimers[id]?.cancel();
      _answerUserTimers.remove(id);
    } else {
      _answerUserTimers.forEach((participantId, timer) => timer.cancel());
      _answerUserTimers.clear();
    }
  }

  _clearCallData() {
    log('[_clearProperties]', TAG);

    _meetingId = null;
    _initiatorId = null;
    _participantIds = null;
    _meetingsCalls.clear();
  }

  _clearCall(int participantId) {
    _participantIds?.remove(participantId);
    if ((_participantIds?.isEmpty ?? false) || participantId == _initiatorId) {
      if (_meetingId != null) {
        CallKitManager.instance
            .processCallFinished(_meetingsCalls[_meetingId!]!);
      }

      _clearCallData();
      _currentCallState = InternalCallState.FINISHED;

      onCloseCall?.call();
    }
  }

  _onCallAccepted(CallEvent callEvent) async {
    log('[_onCallAccepted] _currentCallState: $_currentCallState', TAG);

    if (_currentCallState == InternalCallState.ACCEPTED) return;

    var savedUser = await SharedPrefs.getUser();
    if (savedUser == null) return;

    var meetingId = callEvent.userInfo?['meetingId'];
    if (meetingId == null) return;

    CallManager.instance.startNewIncomingCall(
        context,
        savedUser,
        callEvent.sessionId,
        meetingId,
        callEvent.callType,
        callEvent.callerName,
        callEvent.callerId,
        callEvent.opponentsIds.toList(),
        true);
  }

  _onCallEnded(CallEvent callEvent) {
    log('[_onCallEnded] _currentCallState: $_currentCallState', TAG);

    if (_currentCallState == InternalCallState.FINISHED) return;

    var savedUser = await SharedPrefs.getUser();
    if (savedUser == null) return;

    var meetingId = callEvent.userInfo?['meetingId'];
    if (meetingId == null) return;

    if (_currentCallState == InternalCallState.ACCEPTED) {
      stopCall(savedUser);
    } else {
      reject(callEvent.sessionId, meetingId, false, callEvent.callerId, true);
      onCallRejected?.call(meetingId);
    }
  }

  _onMuteCall(bool mute, String callId) {
    if (!_meetingsCalls.containsValue(callId)) return;

    _meetingsCalls.forEach((key, value) {
      if (value == callId) {
        onCallMuted?.call(key, mute);
      }
    });
  }

  void _sendStartCallSignalForOffliners(String sessionId, String meetingId,
      int callType, String callName, int callerId, Set<int> opponentsIds) {
    CreateEventParams params = _getCallEventParameters(
        sessionId, meetingId, callType, callName, callerId, opponentsIds);
    params.parameters[PARAM_SIGNAL_TYPE] = SIGNAL_TYPE_START_CALL;
    params.parameters[PARAM_IOS_VOIP] = 1;
    params.parameters[PARAM_EXPIRATION] = 0;

    createEvent(params.getEventForRequest()).then((cubeEvent) {
      log("Event for offliners created: $cubeEvent");
    }).catchError((error) {
      log("ERROR occurs during create event");
    });
  }

  CreateEventParams _getCallEventParameters(String sessionId, String meetingId,
      int callType, String callName, int callerId, Set<int> opponentsIds) {
    CreateEventParams params = CreateEventParams();
    params.parameters = {
      'message':
          "Incoming ${callType == CallType.VIDEO_CALL ? "Video" : "Audio"} call",
      PARAM_CALL_TYPE: callType,
      PARAM_SESSION_ID: sessionId,
      PARAM_CALLER_ID: callerId,
      PARAM_CALLER_NAME: callName,
      PARAM_CALL_OPPONENTS: opponentsIds.join(','),
      PARAM_USER_INFO: jsonEncode({'meetingId': meetingId}),
    };

    params.notificationType = NotificationType.PUSH;
    params.environment = CubeEnvironment
        .DEVELOPMENT; // TODO use `DEVELOPMENT` for testing purposes
    // params.environment = kReleaseMode ? CubeEnvironment.PRODUCTION : CubeEnvironment.DEVELOPMENT; // TODO use real in your app
    params.usersIds = opponentsIds.toList();

    return params;
  }

  void _initSignalingListener() {
    initSignalingListener() {
      _systemMessagesManager =
          CubeChatConnection.instance.systemMessagesManager;
      _systemMessagesManager?.systemMessagesStream
          .listen((cubeMessage) => parseCallMessage(cubeMessage));
    }

    if (CubeChatConnection.instance.currentUser != null &&
        CubeChatConnection.instance.chatConnectionState ==
            CubeChatConnectionState.Ready) {
      initSignalingListener();
    } else {
      CubeChatConnection.instance.connectionStateStream.listen((state) {
        if (state == CubeChatConnectionState.Ready) {
          initSignalingListener();
        }
      });
    }
  }

  startNewIncomingCall(
    BuildContext context,
    CubeUser currentUser,
    String callId,
    String meetingId,
    int callType,
    String callName,
    int callerId,
    List<int> opponentsIds,
    bool fromCallKit, {
    MediaStream? initialLocalMediaStream,
    bool isFrontCameraUsed = true,
  }) async {
    this.context = context;
    _currentCallState = InternalCallState.ACCEPTED;

    var participants = Set<int>.from([...opponentsIds, callerId]);
    participants.removeWhere((userId) => userId == currentUser.id!);

    setActiveCall(callId, meetingId, callerId, participants.toList());

    if (fromCallKit) {
      onCallAccepted?.call(meetingId);
    } else {
      CallKitManager.instance.processCallStarted(callId);
    }

    ConferenceSession callSession = await ConferenceClient.instance
        .createCallSession(currentUser.id!, callType: callType);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ConversationCallScreen(
          currentUser,
          callSession,
          meetingId,
          opponentsIds,
          true,
          callName,
          initialLocalMediaStream: initialLocalMediaStream,
          isFrontCameraUsed: isFrontCameraUsed,
        ),
      ),
    );
  }

  static Future<void> startCallIfNeed(BuildContext context) async {
    var savedUser = await SharedPrefs.getUser();
    if (savedUser == null) return;

    CallKitManager.instance.getCallToStart().then((callToStart) async {
      if (callToStart != null && callToStart.userInfo != null) {
        var meetingId = callToStart.userInfo!['meetingId']!;

        CallManager.instance.startNewIncomingCall(
            context,
            savedUser,
            callToStart.sessionId,
            meetingId,
            callToStart.callType,
            callToStart.callerName,
            callToStart.callerId,
            callToStart.opponentsIds.toList(),
            true);
      }
    });
  }

  bool hasActiveCall() {
    return _meetingId != null;
  }

  void setActiveCall(String callId, String meetingId, int initiatorId,
      List<int> participantIds) {
    _meetingId = meetingId;
    _meetingsCalls[meetingId] = callId;
    _initiatorId = initiatorId;
    _participantIds = participantIds;
  }
}

List<CubeMessage> buildCallMessages(
    String callId, String meetingId, List<int?> participantIds) {
  return participantIds.map((userId) {
    var msg = CubeMessage();
    msg.recipientId = userId;
    msg.properties = {'meetingId': meetingId, 'callId': callId};
    return msg;
  }).toList();
}

enum InternalCallState { NEW, REJECTED, ACCEPTED, FINISHED }

typedef void NewCallCallback(String callId, String meetingId, int initiatorId,
    List<int> participantIds, int callType, String callName);
typedef void CloseCall();
typedef void RejectCallCallback(
    String meetingId, int participantId, bool isBusy);
typedef void CallActionCallback(String meetingId);
typedef void UserNotAnswerCallback(int participantId);
typedef void MuteCallCallback(String meetingId, bool isMuted);
