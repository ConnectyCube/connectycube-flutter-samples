import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:universal_io/io.dart';
import 'package:uuid/uuid.dart';

import 'package:connectycube_flutter_call_kit/connectycube_flutter_call_kit.dart';
import 'package:connectycube_sdk/connectycube_sdk.dart';

import '../utils/consts.dart';
import '../utils/pref_util.dart';
import 'callkit_manager.dart';
import 'push_notifications_manager.dart';

const int niAnswerTimerInterval = 60;

class CallManager {
  static const String tag = 'CallManager';
  bool isInitialized = false;
  SystemMessagesManager? _systemMessagesManager;
  NewCallCallback? onReceiveNewCall;
  CloseCall? onCloseCall;
  RejectCallCallback? onReceiveRejectCall;
  AcceptCallCallback? onReceiveAcceptCall;
  CallActionCallback? onCallAccepted;
  CallActionCallback? onCallRejected;
  MuteCallCallback? onCallMuted;
  UserNotAnswerCallback? onUserNotAnswerCallback;
  String? _meetingId;
  List<int>? _participantIds;
  int? _initiatorId;
  final Map<String, String> _meetingsCalls = {};
  InternalCallState? currentCallState;
  Map<String, bool> Function()? getMediaState;
  MediaStateUpdatedCallback? onParticipantMediaUpdated;

  final _answerUserTimers = <int, Timer>{};

  late BuildContext context;

  CallManager._privateConstructor() {
    RTCConfig.instance.statsReportsInterval = 200;
  }

  static final CallManager _instance = CallManager._privateConstructor();

  static CallManager get instance => _instance;

  init(BuildContext context) {
    log('[init]', tag);

    if (isInitialized) return;

    if (Platform.isAndroid || Platform.isIOS) {
      PushNotificationsManager.instance.init();
      CallKitManager.instance.init(
          onCallAccepted: _onCallAccepted,
          onCallEnded: _onCallEnded,
          onMuteCall: _onMuteCall);
    }

    _initSignalingListener();

    isInitialized = true;
  }

  parseCallMessage(CubeMessage cubeMessage) {
    log("parseCallMessage cubeMessage= $cubeMessage");

    if (cubeMessage.senderId == CubeChatConnection.instance.currentUser?.id) {
      return;
    }

    final properties = cubeMessage.properties;
    var meetingId = properties[paramMeetingId];
    var callId = properties[paramSessionId]!;

    if (properties.containsKey(signalTypeStartCall)) {
      var participantIds = properties[paramCallOpponents]!
          .split(',')
          .map((id) => int.parse(id))
          .toList();
      var callType =
          int.tryParse(properties[paramCallType]?.toString() ?? '') ??
              CallType.VIDEO_CALL;
      var callName = properties[paramCallerName] ??
          cubeMessage.senderId?.toString() ??
          'Unknown Caller';
      if (_meetingId == null) {
        currentCallState = InternalCallState.initial;
        onReceiveNewCall?.call(callId, meetingId!, cubeMessage.senderId!,
            participantIds, callType, callName);
      }
    } else if (properties.containsKey(signalTypeAcceptCall)) {
      if (_meetingId == meetingId) {
        handleAcceptCall(cubeMessage.senderId!);
      }
    } else if (properties.containsKey(signalTypeRejectCall)) {
      bool isBusy = properties[paramBusy] == 'true';
      if (_meetingId == meetingId) {
        handleRejectCall(meetingId!, cubeMessage.senderId!, isBusy);
      }
    } else if (properties.containsKey(signalTypeEndCall)) {
      processCallFinishedByParticipant(
          cubeMessage.senderId!, callId, meetingId!);
    } else if (properties.containsKey(signalTypeUpdateMediaState)) {
      if (_meetingId == meetingId &&
          properties.containsKey(paramMediaConfig)) {
        var mediaConfig =
            Map<String, bool>.from(jsonDecode(properties[paramMediaConfig]!));
        onParticipantMediaUpdated?.call(cubeMessage.senderId!, mediaConfig);
      }
    } else if (properties.containsKey(signalTypeRequestMediaState)) {
      if (_meetingId == meetingId) {
        var mediaConfig = getMediaState?.call();

        if (mediaConfig != null) {
          sendMediaUpdatedMessage(
              callId, meetingId!, [cubeMessage.senderId!], mediaConfig);
        }
      }
    }
  }

  startNewOutgoingCall(String meetingId, List<int> participantIds,
      int currentUserId, int callType, String callName, String? callPhoto) {
    _initiatorId = currentUserId;
    _participantIds = participantIds;
    _meetingId = meetingId;
    _meetingsCalls[_meetingId!] = const Uuid().v4();
    currentCallState = InternalCallState.initial;
    sendCallMessage(_meetingsCalls[_meetingId!]!, meetingId, participantIds,
        callType, callName);
    startNoAnswerTimers(participantIds);
    _sendStartCallSignalForOffliners(_meetingsCalls[_meetingId!]!, meetingId,
        callType, callName, callPhoto, currentUserId, participantIds.toSet());
  }

  reject(String callId, String meetingId, bool isBusy, int initiatorId,
      bool fromCallKit) {
    currentCallState = InternalCallState.rejected;
    sendRejectMessage(callId, meetingId, isBusy, initiatorId);

    if (!fromCallKit) {
      CallKitManager.instance.processCallFinished(callId);
    }

    _clearCallData();
  }

  stopCall(CubeUser currentUser) {
    currentCallState = InternalCallState.finished;

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
      currentCallState = InternalCallState.finished;

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
    for (var callMsg in callMsgList) {
      callMsg.properties[signalTypeStartCall] = '1';
      callMsg.properties[paramCallOpponents] = participantIds.join(',');
      callMsg.properties[paramCallType] = callType.toString();
      callMsg.properties[paramCallerName] = callName;
    }
    for (var msg in callMsgList) {
      sendSystemMessage(msg.recipientId!, msg.properties);
    }
  }

  sendAcceptMessage(String callId, String meetingId, int participantId) {
    List<CubeMessage> callMsgList =
        buildCallMessages(callId, meetingId, [participantId]);
    for (var callMsg in callMsgList) {
      callMsg.properties[signalTypeAcceptCall] = '1';
    }
    for (var msg in callMsgList) {
      sendSystemMessage(msg.recipientId!, msg.properties);
    }
  }

  sendRejectMessage(
      String callId, String meetingId, bool isBusy, int participantId) {
    List<CubeMessage> callMsgList =
        buildCallMessages(callId, meetingId, [participantId]);
    for (var callMsg in callMsgList) {
      callMsg.properties[signalTypeRejectCall] = '1';
      callMsg.properties[paramBusy] = isBusy.toString();
    }
    for (var msg in callMsgList) {
      sendSystemMessage(msg.recipientId!, msg.properties);
    }
  }

  sendEndCallMessage(
      String callId, String meetingId, List<int> participantIds) {
    List<CubeMessage> callMsgList =
        buildCallMessages(callId, meetingId, participantIds);
    for (var callMsg in callMsgList) {
      callMsg.properties[signalTypeEndCall] = '1';
    }
    for (var msg in callMsgList) {
      sendSystemMessage(msg.recipientId!, msg.properties);
    }
  }

  sendMediaUpdatedMessage(String callId, String meetingId,
      List<int> participantIds, Map<String, bool> mediaConfig) {
    List<CubeMessage> callMsgList =
        buildCallMessages(callId, meetingId, participantIds);
    for (var callMsg in callMsgList) {
      callMsg.properties[signalTypeUpdateMediaState] = '1';
      callMsg.properties[paramMediaConfig] = jsonEncode(mediaConfig);
    }
    for (var msg in callMsgList) {
      sendSystemMessage(msg.recipientId!, msg.properties);
    }
  }

  sendRequestMediaConfigMessage(
      String callId, String meetingId, List<int> participantIds) {
    List<CubeMessage> callMsgList =
        buildCallMessages(callId, meetingId, participantIds);
    for (var callMsg in callMsgList) {
      callMsg.properties[signalTypeRequestMediaState] = '1';
    }
    for (var msg in callMsgList) {
      sendSystemMessage(msg.recipientId!, msg.properties);
    }
  }

  muteMic(String meetingId, bool mute) {
    CallKitManager.instance.muteMic(_meetingsCalls[meetingId]!, mute);
  }

  handleAcceptCall(int participantId) {
    _clearNoAnswerTimers(id: participantId);
    onReceiveAcceptCall?.call(participantId);
    if (!(_participantIds?.contains(participantId) ?? false)) {
      _participantIds?.add(participantId);
    }
  }

  handleRejectCall(String meetingId, int participantId, isBusy) {
    onReceiveRejectCall?.call(meetingId, participantId, isBusy);
    _clearNoAnswerTimers(id: participantId);
    _clearCall(participantId);
  }

  startNoAnswerTimers(participantIds) {
    participantIds.forEach((userId) => {
          _answerUserTimers[userId] = Timer(
              const Duration(seconds: niAnswerTimerInterval),
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
    log('[_clearProperties]', tag);

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
      currentCallState = InternalCallState.finished;

      onCloseCall?.call();
    }
  }

  _onCallAccepted(CallEvent callEvent) async {
    log('[_onCallAccepted] _currentCallState: $currentCallState', tag);

    if (currentCallState == InternalCallState.accepted) return;

    SharedPrefs.getUser().then((savedUser) {
      if (savedUser == null) return;

      var meetingId = callEvent.userInfo?[paramMeetingId];
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
        true,
        cleanNavigation: false,
      );
    });
  }

  _onCallEnded(CallEvent callEvent) async {
    log('[_onCallEnded] _currentCallState: $currentCallState', tag);

    if (currentCallState == InternalCallState.finished ||
        currentCallState == InternalCallState.rejected) return;

    var savedUser = await SharedPrefs.getUser();
    if (savedUser == null) return;

    var meetingId = callEvent.userInfo?[paramMeetingId];
    if (meetingId == null) return;

    if (currentCallState == InternalCallState.accepted) {
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

  void _sendStartCallSignalForOffliners(
    String sessionId,
    String meetingId,
    int callType,
    String callName,
    String? callPhoto,
    int callerId,
    Set<int> opponentsIds,
  ) {
    CreateEventParams params = _getCallEventParameters(sessionId, meetingId,
        callType, callName, callPhoto, callerId, opponentsIds);
    params.parameters[paramSignalType] = signalTypeStartCall;
    params.parameters[paramIosVoip] = 1;
    params.parameters[paramExpiration] = 0;

    createEvent(params.getEventForRequest()).then((cubeEvent) {
      log("Event for offliners created: $cubeEvent");
    }).catchError((error) {
      log("ERROR occurs during create event");
    });
  }

  CreateEventParams _getCallEventParameters(
    String sessionId,
    String meetingId,
    int callType,
    String callName,
    String? callPhoto,
    int callerId,
    Set<int> opponentsIds,
  ) {
    CreateEventParams params = CreateEventParams();
    params.parameters = {
      'message':
          "Incoming ${callType == CallType.VIDEO_CALL ? "Video" : "Audio"} call",
      paramCallType: callType,
      paramSessionId: sessionId,
      paramCallerId: callerId,
      paramCallerName: callName,
      paramCallOpponents: opponentsIds.join(','),
      paramPhotoUrl: callPhoto,
      paramUserInfo: jsonEncode({
        paramMeetingId: meetingId,
      }),
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
      _systemMessagesManager?.systemMessagesStream.listen(parseCallMessage);
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
    bool cleanNavigation = true,
    MediaStream? initialLocalMediaStream,
    bool isFrontCameraUsed = true,
  }) async {
    currentCallState = InternalCallState.accepted;

    var participants = <int>{...opponentsIds, callerId};
    participants.removeWhere((userId) => userId == currentUser.id!);

    setActiveCall(callId, meetingId, callerId, participants.toList());

    sendAcceptMessage(callId, meetingId, callerId);

    if (fromCallKit) {
      onCallAccepted?.call(meetingId);
    } else {
      CallKitManager.instance.processCallStarted(callId);
    }

    ConferenceClient.instance
        .createCallSession(currentUser.id!, callType: callType)
        .then((callSession) {
      var arguments = {
        argUser: currentUser,
        argCallSession: callSession,
        argMeetingId: meetingId,
        argOpponents: opponentsIds,
        argIsIncoming: true,
        argCallName: callName,
        argInitialLocalMediaStream: initialLocalMediaStream,
        argIsFrontCameraUsed: isFrontCameraUsed
      };

      if (cleanNavigation) {
        Navigator.of(context)
            .pushReplacementNamed(conversationScreen, arguments: arguments);
      } else {
        Navigator.of(context)
            .pushNamed(conversationScreen, arguments: arguments);
      }
    });
  }

  static Future<void> startCallIfNeed(BuildContext context) async {
    var savedUser = await SharedPrefs.getUser();
    if (savedUser == null) return;

    CallKitManager.instance.getCallToStart().then((callToStart) async {
      if (callToStart != null && callToStart.userInfo != null) {
        var meetingId = callToStart.userInfo![paramMeetingId]!;

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

  void notifyParticipantsMediaUpdated(Map<String, bool> mediaConfig) {
    if (_meetingId == null) return;

    sendMediaUpdatedMessage(_meetingsCalls[_meetingId]!, _meetingId!,
        _participantIds!, mediaConfig);
  }

  void processParticipantLeave(int participant) {
    _participantIds?.remove(participant);
  }

  void requestParticipantsMediaConfig(List<int?> participants) {
    if (_meetingId == null) return;
    participants.removeWhere((userId) => userId == null);

    if (participants.isEmpty) return;

    sendRequestMediaConfigMessage(
        _meetingsCalls[_meetingId]!, _meetingId!, List<int>.from(participants));

    _participantIds?.addAll(participants
        .where((userId) =>
            userId != null && !(_participantIds?.contains(userId) ?? true))
        .map((e) => e!));
  }
}

List<CubeMessage> buildCallMessages(
    String callId, String meetingId, List<int?> participantIds) {
  return participantIds.where((userId) {
    if (userId == null || userId <= 0) {
      return false;
    }

    return userId != CubeSessionManager.instance.activeSession?.userId;
  }).map((userId) {
    var msg = CubeMessage();
    msg.recipientId = userId;
    msg.properties = {paramMeetingId: meetingId, paramSessionId: callId};
    return msg;
  }).toList();
}

enum InternalCallState { initial, rejected, accepted, finished }

typedef NewCallCallback = void Function(String callId, String meetingId,
    int initiatorId, List<int> participantIds, int callType, String callName);
typedef CloseCall = void Function();
typedef RejectCallCallback = void Function(
    String meetingId, int participantId, bool isBusy);
typedef AcceptCallCallback = void Function(int participantId);
typedef CallActionCallback = void Function(String meetingId);
typedef UserNotAnswerCallback = void Function(int participantId);
typedef MuteCallCallback = void Function(String meetingId, bool isMuted);
typedef MediaStateUpdatedCallback = void Function(
    int userId, Map<String, bool> mediaConfig);
