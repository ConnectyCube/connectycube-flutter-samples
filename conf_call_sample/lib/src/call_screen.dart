import 'package:conf_call_sample/src/utils/call_manager.dart';
import 'package:conf_call_sample/src/utils/video_config.dart';
import 'package:flutter/material.dart';

import 'package:connectycube_sdk/connectycube_sdk.dart';

class IncomingCallScreen extends StatelessWidget {
  static const String TAG = "IncomingCallScreen";
  String _roomId;
  List<int> _participantIds;

  IncomingCallScreen(this._roomId, this._participantIds);

  @override
  Widget build(BuildContext context) {
    CallManager.instance.onCloseCall = () {
      log("onCloseCall", TAG);
      Navigator.pop(context);
    };

    return WillPopScope(
        onWillPop: () => _onBackPressed(context),
        child: Scaffold(
            body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Padding(
                padding: EdgeInsets.all(36),
                child: Text(_getCallTitle(), style: TextStyle(fontSize: 28)),
              ),
              Padding(
                padding: EdgeInsets.only(top: 36, bottom: 8),
                child: Text("Members:", style: TextStyle(fontSize: 20)),
              ),
              Padding(
                padding: EdgeInsets.only(bottom: 86),
                child: Text(_participantIds.join(", "),
                    style: TextStyle(fontSize: 18)),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Padding(
                    padding: EdgeInsets.only(right: 36),
                    child: FloatingActionButton(
                      heroTag: "RejectCall",
                      child: Icon(
                        Icons.call_end,
                        color: Colors.white,
                      ),
                      backgroundColor: Colors.red,
                      onPressed: () => _rejectCall(context),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(left: 36),
                    child: FloatingActionButton(
                      heroTag: "AcceptCall",
                      child: Icon(
                        Icons.call,
                        color: Colors.white,
                      ),
                      backgroundColor: Colors.green,
                      onPressed: () => _acceptCall(context),
                    ),
                  ),
                ],
              ),
            ],
          ),
        )));
  }

  _getCallTitle() {
    String callType = "Video";
    return "Incoming $callType call";
  }

  void _acceptCall(BuildContext context) async {
    ConferenceSession callSession = await ConferenceClient.instance
        .createCallSession(CubeChatConnection.instance.currentUser.id);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) =>
            ConversationCallScreen(callSession, _roomId, _participantIds, true),
      ),
    );
  }

  void _rejectCall(BuildContext context) {
    CallManager.instance.reject(_roomId, false);
    Navigator.pop(context);
  }

  Future<bool> _onBackPressed(BuildContext context) {
    return Future.value(false);
  }
}

class ConversationCallScreen extends StatefulWidget {
  final ConferenceSession _callSession;
  final String roomId;
  final List<int> opponents;
  final bool _isIncoming;

  @override
  State<StatefulWidget> createState() {
    return _ConversationCallScreenState(
        _callSession, roomId, opponents, _isIncoming);
  }

  ConversationCallScreen(
      this._callSession, this.roomId, this.opponents, this._isIncoming);
}

class _ConversationCallScreenState extends State<ConversationCallScreen>
    implements RTCSessionStateCallback<ConferenceSession> {
  static const String TAG = "_ConversationCallScreenState";
  ConferenceSession _callSession;
  CallManager _callManager = CallManager.instance;
  bool _isIncoming;
  String roomId;
  final List<int> opponents;
  bool _isCameraEnabled = true;
  bool _isSpeakerEnabled = true;
  bool _isMicMute = false;

  Map<int, RTCVideoRenderer> streams = {};

  _ConversationCallScreenState(
      this._callSession, this.roomId, this.opponents, this._isIncoming);

  @override
  void initState() {
    super.initState();
    _initCustomMediaConfigs();
    _callManager.onReceiveRejectCall = _onReceiveRejectCall;
    _callManager.onCloseCall = _onCloseCall;

    _callSession.onLocalStreamReceived = _addLocalMediaStream;
    _callSession.onRemoteStreamReceived = _addRemoteMediaStream;
    _callSession.onSessionClosed = _onSessionClosed;
    _callSession.onPublishersReceived = onPublishersReceived;
    _callSession.onPublisherLeft = onPublisherLeft;
    _callSession.onError = onError;

    _callSession.setSessionCallbacksListener(this);

    _callSession.joinDialog(roomId, ((publishers) {
      log("join session= $publishers", TAG);

      if (!_isIncoming) {
        _callManager.startCall(roomId, opponents, _callSession.currentUserId);
      }
    }));
  }

  @override
  void dispose() {
    super.dispose();
    streams.forEach((opponentId, stream) async {
      log("[dispose] dispose renderer for $opponentId", TAG);
      await stream.dispose();
    });
  }

  void _onCloseCall() {
    log("_onCloseCall", TAG);
    _callSession.leave();
  }

  void _onReceiveRejectCall(String roomId, int participantId, bool isBusy) {
    log("_onReceiveRejectCall got reject from user $participantId", TAG);
  }

  void _addLocalMediaStream(MediaStream stream) {
    log("_addLocalMediaStream", TAG);
    _onStreamAdd(ConferenceClient.instance.currentUserId, stream);
  }

  void _addRemoteMediaStream(session, int userId, MediaStream stream) {
    log("_addRemoteMediaStream for user $userId", TAG);
    _onStreamAdd(userId, stream);
  }

  void _removeMediaStream(callSession, int userId) {
    log("_removeMediaStream for user $userId", TAG);
    RTCVideoRenderer videoRenderer = streams[userId];
    if (videoRenderer == null) return;

    videoRenderer.srcObject = null;
    videoRenderer.dispose();

    setState(() {
      streams.remove(userId);
    });
  }

  void _closeSessionIfLast() {
    if (_callSession.allActivePublishers.length < 1) {
      _callManager.stopCall();
      _callSession.removeSessionCallbacksListener();
      _callSession.leave();
    }
  }

  void _onSessionClosed(session) {
    log("_onSessionClosed", TAG);
    _callSession.removeSessionCallbacksListener();
    (session as ConferenceSession).leave();
    Navigator.pop(context);
  }

  void onPublishersReceived(publishers) {
    log("onPublishersReceived", TAG);
    subscribeToPublishers(publishers);
    handlePublisherReceived(publishers);
  }

  void onPublisherLeft(publisher) {
    log("onPublisherLeft $publisher", TAG);
  }

  void onError(ex) {
    log("onError $ex", TAG);
  }

  void _onStreamAdd(int opponentId, MediaStream stream) async {
    log("_onStreamAdd for user $opponentId", TAG);

    RTCVideoRenderer streamRender = RTCVideoRenderer();
    await streamRender.initialize();
    streamRender.srcObject = stream;
    setState(() => streams[opponentId] = streamRender);
  }

  void subscribeToPublishers(List<int> publishers) {
    for (int publisher in publishers) {
      _callSession.subscribeToPublisher(publisher);
    }
  }

  void handlePublisherReceived(List<int> publishers) {
    if (!_isIncoming) {
      publishers.forEach((id) => _callManager.handleAcceptCall(id));
    }
  }

  List<Widget> renderStreamsGrid(Orientation orientation) {
    List<Widget> streamsExpanded = streams.entries
        .map(
          (entry) => Expanded(
            child: RTCVideoView(
              entry.value,
              mirror: true,
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
            ),
          ),
        )
        .toList();
    if (streams.length > 2) {
      List<Widget> rows = [];

      for (var i = 0; i < streamsExpanded.length; i += 2) {
        var chunkEndIndex = i + 2;

        if (streamsExpanded.length < chunkEndIndex) {
          chunkEndIndex = streamsExpanded.length;
        }

        var chunk = streamsExpanded.sublist(i, chunkEndIndex);

        rows.add(
          Expanded(
            child: orientation == Orientation.portrait
                ? Row(children: chunk)
                : Column(children: chunk),
          ),
        );
      }

      return rows;
    }

    return streamsExpanded;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () => _onBackPressed(context),
      child: Stack(
        children: [
          Scaffold(
              body: _isVideoCall()
                  ? OrientationBuilder(
                      builder: (context, orientation) {
                        return Center(
                          child: Container(
                            child: orientation == Orientation.portrait
                                ? Column(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    children: renderStreamsGrid(orientation))
                                : Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    children: renderStreamsGrid(orientation)),
                          ),
                        );
                      },
                    )
                  : Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Padding(
                            padding: EdgeInsets.only(bottom: 24),
                            child: Text(
                              "Audio call",
                              style: TextStyle(fontSize: 28),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.only(bottom: 12),
                            child: Text(
                              "Members:",
                              style: TextStyle(
                                  fontSize: 20, fontStyle: FontStyle.italic),
                            ),
                          ),
                          Text(
                            _callSession.allActivePublishers.join(", "),
                            style: TextStyle(fontSize: 20),
                          ),
                        ],
                      ),
                    )),
          Align(
            alignment: Alignment.bottomCenter,
            child: _getActionsPanel(),
          ),
        ],
      ),
    );
  }

  Widget _getActionsPanel() {
    return Container(
      margin: EdgeInsets.only(bottom: 16, left: 8, right: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(32),
            bottomRight: Radius.circular(32),
            topLeft: Radius.circular(32),
            topRight: Radius.circular(32)),
        child: Container(
          padding: EdgeInsets.all(4),
          color: Colors.black26,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Padding(
                padding: EdgeInsets.only(right: 4),
                child: FloatingActionButton(
                  elevation: 0,
                  heroTag: "Mute",
                  child: Icon(
                    Icons.mic,
                    color: _isMicMute ? Colors.grey : Colors.white,
                  ),
                  onPressed: () => _muteMic(),
                  backgroundColor: Colors.black38,
                ),
              ),
              Padding(
                padding: EdgeInsets.only(right: 4),
                child: FloatingActionButton(
                  elevation: 0,
                  heroTag: "Speacker",
                  child: Icon(
                    Icons.volume_up,
                    color: _isSpeakerEnabled ? Colors.white : Colors.grey,
                  ),
                  onPressed: () => _switchSpeaker(),
                  backgroundColor: Colors.black38,
                ),
              ),
              Padding(
                padding: EdgeInsets.only(right: 4),
                child: FloatingActionButton(
                  elevation: 0,
                  heroTag: "SwitchCamera",
                  child: Icon(
                    Icons.switch_video,
                    color: _isVideoEnabled() ? Colors.white : Colors.grey,
                  ),
                  onPressed: () => _switchCamera(),
                  backgroundColor: Colors.black38,
                ),
              ),
              Padding(
                padding: EdgeInsets.only(right: 4),
                child: FloatingActionButton(
                  elevation: 0,
                  heroTag: "ToggleCamera",
                  child: Icon(
                    Icons.videocam,
                    color: _isVideoEnabled() ? Colors.white : Colors.grey,
                  ),
                  onPressed: () => _toggleCamera(),
                  backgroundColor: Colors.black38,
                ),
              ),
              Expanded(
                child: SizedBox(),
                flex: 1,
              ),
              Padding(
                padding: EdgeInsets.only(left: 0),
                child: FloatingActionButton(
                  child: Icon(
                    Icons.call_end,
                    color: Colors.white,
                  ),
                  backgroundColor: Colors.red,
                  onPressed: () => _endCall(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  _endCall() {
    _callManager.stopCall();
    _callSession.leave();
  }

  Future<bool> _onBackPressed(BuildContext context) {
    return Future.value(false);
  }

  _muteMic() {
    setState(() {
      _isMicMute = !_isMicMute;
      _callSession.setMicrophoneMute(_isMicMute);
    });
  }

  _switchCamera() {
    if (!_isVideoEnabled()) return;

    _callSession.switchCamera();
  }

  _toggleCamera() {
    if (!_isVideoCall()) return;

    setState(() {
      _isCameraEnabled = !_isCameraEnabled;
      _callSession.setVideoEnabled(_isCameraEnabled);
    });
  }

  bool _isVideoEnabled() {
    return _isVideoCall() && _isCameraEnabled;
  }

  bool _isVideoCall() {
    return CallType.VIDEO_CALL == _callSession.callType;
  }

  _switchSpeaker() {
    setState(() {
      _isSpeakerEnabled = !_isSpeakerEnabled;
      _callSession.enableSpeakerphone(_isSpeakerEnabled);
    });
  }

  void _initCustomMediaConfigs() {
    RTCMediaConfig mediaConfig = RTCMediaConfig.instance;
    if (opponents.length == 1) {
      mediaConfig.minHeight = HD_VIDEO.height;
      mediaConfig.minWidth = HD_VIDEO.width;
    } else if (opponents.length <= 3) {
      mediaConfig.minHeight = VGA_VIDEO.height;
      mediaConfig.minWidth = VGA_VIDEO.width;
    } else {
      mediaConfig.minHeight = QVGA_VIDEO.height;
      mediaConfig.minWidth = QVGA_VIDEO.width;
    }
    mediaConfig.minFrameRate = 30;
  }

  @override
  void onConnectedToUser(ConferenceSession session, int userId) {
    log("onConnectedToUser userId= $userId");
  }

  @override
  void onConnectionClosedForUser(ConferenceSession session, int userId) {
    log("onConnectionClosedForUser userId= $userId");
    _removeMediaStream(session, userId);
    _closeSessionIfLast();
  }

  @override
  void onDisconnectedFromUser(ConferenceSession session, int userId) {
    log("onDisconnectedFromUser userId= $userId");
  }
}
