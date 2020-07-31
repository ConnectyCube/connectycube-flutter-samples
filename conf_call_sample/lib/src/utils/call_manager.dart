import 'dart:async';

import 'package:connectycube_sdk/connectycube_chat.dart';

const NO_ANSWER_TIMER_INTERVAL = 30;

class CallManager {
  SystemMessagesManager _systemMessagesManager;
  NewCallCallback onReceiveNewCall;
  CloseCall onCloseCall;
  RejectCallCallback onReceiveRejectCall;
  UserNotAnswerCallback onUserNotAnswerCallback;
  String _roomId;
  List<int> _participantIds;
  int _initiatorId;

  var _answerUserTimers = Map<int,Timer>();

  CallManager._privateConstructor() {
    _systemMessagesManager = CubeChatConnection.instance.systemMessagesManager;
    _systemMessagesManager.systemMessagesStream.listen((cubeMessage) =>
        parseCallMessage(cubeMessage));
  }

  static final CallManager _instance = CallManager._privateConstructor();

  static CallManager get instance => _instance;

  parseCallMessage(CubeMessage cubeMessage) {
    log("parseCallMessage cubeMessage= $cubeMessage");
    final properties = cubeMessage.properties;
    if(properties.containsKey("callStart")) {
      String roomId = properties["janusRoomId"];
      List<int> participantIds = properties["participantIds"].split(',').map((id) => int.parse(id)).toList();
      if(_roomId == null) {
        _roomId = roomId;
        _initiatorId = cubeMessage.senderId;
        _participantIds = participantIds;
        if(onReceiveNewCall != null) onReceiveNewCall(roomId, participantIds);
      }
    } else if(properties.containsKey("callAccepted")) {
      String roomId = properties["janusRoomId"];
      if(_roomId == roomId) {
        _clearNoAnswerTimers(id: cubeMessage.senderId);
      }
    } else if(properties.containsKey("callRejected")) {
      String roomId = properties["janusRoomId"];
      bool isBusy = properties["busy"] == 'true';
      if(_roomId == roomId) {
        if(onReceiveRejectCall != null) onReceiveRejectCall(roomId, cubeMessage.senderId, isBusy);
        handleRejectCall(cubeMessage.senderId, isBusy);
      }
    } else if(properties.containsKey("callEnd")) {
      String roomId = properties["janusRoomId"];
      if(_roomId == roomId) {
        _clearCall(cubeMessage.senderId);
      }
    }
  }

  startCall(String roomId, List<int> participantIds, int currentUserId) {
    _initiatorId = currentUserId;
    _participantIds = participantIds;
    _roomId = roomId;
    sendCallMessage(roomId, participantIds);
    startNoAnswerTimers(participantIds);
  }

  acceptCall(String roomId, int participantId) {
    sendAcceptMessage(roomId, participantId);
  }

  reject(String roomId, bool isBusy) {
    sendRejectMessage(roomId, isBusy, _initiatorId);
    _clearProperties();
  }

  stopCall() {
    _clearNoAnswerTimers();
    sendEndCallMessage(_roomId, _participantIds);
    _clearProperties();
  }

  sendCallMessage(String roomId, List<int> participantIds) {
    List<CubeMessage> callMsgList = _buildCallMessages(roomId, participantIds);
    callMsgList.forEach((callMsg) {
      callMsg.properties["callStart"] = '1';
      callMsg.properties["participantIds"] = participantIds.join(',');
    });
    callMsgList.forEach((msg) => _systemMessagesManager.sendSystemMessage(msg));
  }

  sendAcceptMessage(String roomId, int participantId) {
    List<CubeMessage> callMsgList = _buildCallMessages(roomId, [participantId]);
    callMsgList.forEach((callMsg){
      callMsg.properties["callAccepted"] = '1';
    });
    callMsgList.forEach((msg) => _systemMessagesManager.sendSystemMessage(msg));
  }

  sendRejectMessage(String roomId, bool isBusy, int participantId) {
    List<CubeMessage> callMsgList = _buildCallMessages(roomId, [participantId]);
    callMsgList.forEach((callMsg) {
      callMsg.properties["callRejected"] = '1';
      callMsg.properties["busy"] = isBusy.toString();
    });
    callMsgList.forEach((msg) => _systemMessagesManager.sendSystemMessage(msg));
  }

  sendEndCallMessage(String roomId, List<int> participantIds) {
    List<CubeMessage> callMsgList = _buildCallMessages(roomId, participantIds);
    callMsgList.forEach((callMsg) {
      callMsg.properties["callEnd"] = '1';
    });
    callMsgList.forEach((msg) => _systemMessagesManager.sendSystemMessage(msg));
  }

  List<CubeMessage> _buildCallMessages(String roomId, List<int> participantIds) {
    return participantIds.map((userId) {
      var msg = CubeMessage();
      msg.recipientId = userId;
      msg.properties = {"janusRoomId": roomId};
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
    participantIds.forEach((userId) =>
    {
      _answerUserTimers[userId] =
          Timer(Duration(seconds: NO_ANSWER_TIMER_INTERVAL), () => noUserAnswer(userId))
    });
  }

  noUserAnswer(int participantId) {
    if(onUserNotAnswerCallback != null) onUserNotAnswerCallback(participantId);
    _clearNoAnswerTimers(id: participantId);
    sendEndCallMessage(_roomId, [participantId]);
    _clearCall(participantId);
  }

  _clearNoAnswerTimers({int id = 0}) {
    if (id != 0) {
      _answerUserTimers[id].cancel();
      _answerUserTimers.remove(id);
    } else {
      _answerUserTimers.forEach((participantId, timer) => timer.cancel());
      _answerUserTimers.clear();
    }
  }

  _clearProperties() {
    _roomId = null;
    _initiatorId = null;
    _participantIds = null;
  }

  _clearCall(int participantId) {
    _participantIds.remove(participantId);
    if(_participantIds.isEmpty || participantId == _initiatorId) {
      _clearProperties();
      if(onCloseCall != null) onCloseCall();
    }
  }
}
typedef void NewCallCallback(String roomId, List<int> participantIds);
typedef void CloseCall();
typedef void RejectCallCallback(String roomId, int participantId, bool isBusy);
typedef void UserNotAnswerCallback(int participantId);