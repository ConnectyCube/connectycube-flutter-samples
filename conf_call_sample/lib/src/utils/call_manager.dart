import 'dart:async';

import 'package:connectycube_sdk/connectycube_chat.dart';

const NO_ANSWER_TIMER_INTERVAL = 30;

class CallManager {
  SystemMessagesManager? _systemMessagesManager;
  NewCallCallback? onReceiveNewCall;
  CloseCall? onCloseCall;
  RejectCallCallback? onReceiveRejectCall;
  UserNotAnswerCallback? onUserNotAnswerCallback;
  String? _meetingId;
  List<int>? _participantIds;
  int? _initiatorId;

  var _answerUserTimers = Map<int, Timer>();

  CallManager._privateConstructor() {
    _systemMessagesManager = CubeChatConnection.instance.systemMessagesManager;
    _systemMessagesManager!.systemMessagesStream
        .listen((cubeMessage) => parseCallMessage(cubeMessage));
  }

  static final CallManager _instance = CallManager._privateConstructor();

  static CallManager get instance => _instance;

  parseCallMessage(CubeMessage cubeMessage) {
    log("parseCallMessage cubeMessage= $cubeMessage");
    final properties = cubeMessage.properties;
    var meetingId = properties["meetingId"];

    if (properties.containsKey("callStart")) {
      var participantIds = properties["participantIds"]!
          .split(',')
          .map((id) => int.parse(id))
          .toList();
      if (_meetingId == null) {
        _meetingId = meetingId;
        _initiatorId = cubeMessage.senderId;
        _participantIds = participantIds;
        if (onReceiveNewCall != null) {
          onReceiveNewCall!(meetingId!, participantIds);
        }
      }
    } else if (properties.containsKey("callAccepted")) {
      if (_meetingId == meetingId) {
        _clearNoAnswerTimers(id: cubeMessage.senderId!);
      }
    } else if (properties.containsKey("callRejected")) {
      bool isBusy = properties["busy"] == 'true';
      if (_meetingId == meetingId) {
        if (onReceiveRejectCall != null) {
          onReceiveRejectCall!(meetingId!, cubeMessage.senderId!, isBusy);
        }

        handleRejectCall(cubeMessage.senderId!, isBusy);
      }
    } else if (properties.containsKey("callEnd")) {
      if (_meetingId == meetingId) {
        _clearCall(cubeMessage.senderId!);
      }
    }
  }

  startCall(String meetingId, List<int> participantIds, int currentUserId) {
    _initiatorId = currentUserId;
    _participantIds = participantIds;
    _meetingId = meetingId;
    sendCallMessage(meetingId, participantIds);
    startNoAnswerTimers(participantIds);
  }

  acceptCall(String meetingId, int participantId) {
    sendAcceptMessage(meetingId, participantId);
  }

  reject(String meetingId, bool isBusy) {
    sendRejectMessage(meetingId, isBusy, _initiatorId!);
    _clearProperties();
  }

  stopCall() {
    _clearNoAnswerTimers();
    sendEndCallMessage(_meetingId!, _participantIds!);
    _clearProperties();
  }

  sendCallMessage(String meetingId, List<int> participantIds) {
    List<CubeMessage> callMsgList =
        _buildCallMessages(meetingId, participantIds);
    callMsgList.forEach((callMsg) {
      callMsg.properties['callStart'] = '1';
      callMsg.properties['participantIds'] = participantIds.join(',');
    });
    callMsgList
        .forEach((msg) => _systemMessagesManager!.sendSystemMessage(msg));
  }

  sendAcceptMessage(String meetingId, int participantId) {
    List<CubeMessage> callMsgList =
        _buildCallMessages(meetingId, [participantId]);
    callMsgList.forEach((callMsg) {
      callMsg.properties['callAccepted'] = '1';
    });
    callMsgList
        .forEach((msg) => _systemMessagesManager!.sendSystemMessage(msg));
  }

  sendRejectMessage(String meetingId, bool isBusy, int participantId) {
    List<CubeMessage> callMsgList =
        _buildCallMessages(meetingId, [participantId]);
    callMsgList.forEach((callMsg) {
      callMsg.properties['callRejected'] = '1';
      callMsg.properties['busy'] = isBusy.toString();
    });
    callMsgList
        .forEach((msg) => _systemMessagesManager!.sendSystemMessage(msg));
  }

  sendEndCallMessage(String meetingId, List<int> participantIds) {
    List<CubeMessage> callMsgList =
        _buildCallMessages(meetingId, participantIds);
    callMsgList.forEach((callMsg) {
      callMsg.properties['callEnd'] = '1';
    });
    callMsgList
        .forEach((msg) => _systemMessagesManager!.sendSystemMessage(msg));
  }

  List<CubeMessage> _buildCallMessages(
      String meetingId, List<int?> participantIds) {
    return participantIds.map((userId) {
      var msg = CubeMessage();
      msg.recipientId = userId;
      msg.properties = {'meetingId': meetingId};
      return msg;
    }).toList();
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
    if (onUserNotAnswerCallback != null)
      onUserNotAnswerCallback!(participantId);
    _clearNoAnswerTimers(id: participantId);
    sendEndCallMessage(_meetingId!, [participantId]);
    _clearCall(participantId);
  }

  _clearNoAnswerTimers({int id = 0}) {
    if (id != 0) {
      _answerUserTimers[id]!.cancel();
      _answerUserTimers.remove(id);
    } else {
      _answerUserTimers.forEach((participantId, timer) => timer.cancel());
      _answerUserTimers.clear();
    }
  }

  _clearProperties() {
    _meetingId = null;
    _initiatorId = null;
    _participantIds = null;
  }

  _clearCall(int participantId) {
    _participantIds!.remove(participantId);
    if (_participantIds!.isEmpty || participantId == _initiatorId) {
      _clearProperties();
      if (onCloseCall != null) onCloseCall!();
    }
  }
}

typedef void NewCallCallback(String meetingId, List<int> participantIds);
typedef void CloseCall();
typedef void RejectCallCallback(
    String meetingId, int participantId, bool isBusy);
typedef void UserNotAnswerCallback(int participantId);
