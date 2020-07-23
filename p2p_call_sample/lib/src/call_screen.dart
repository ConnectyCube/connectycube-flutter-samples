import 'package:flutter/material.dart';

import 'package:connectycube_sdk/connectycube_sdk.dart';

class IncomingCallScreen extends StatelessWidget {
  static const String TAG = "IncomingCallScreen";
  final CallSession _callSession;

  IncomingCallScreen(this._callSession);

  @override
  Widget build(BuildContext context) {
    _callSession.onSessionClosed = (callSession) {
      log("_onSessionClosed", TAG);
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
                child: Text(_callSession.opponentsIds.join(", "),
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
                      onPressed: () => _rejectCall(context, _callSession),
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
                      onPressed: () => _acceptCall(context, _callSession),
                    ),
                  ),
                ],
              ),
            ],
          ),
        )));
  }

  _getCallTitle() {
    String callType;

    switch (_callSession.callType) {
      case CallType.VIDEO_CALL:
        callType = "Video";
        break;
      case CallType.AUDIO_CALL:
        callType = "Audio";
        break;
    }

    return "Incoming $callType call";
  }

  void _acceptCall(BuildContext context, CallSession callSession) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ConversationCallScreen(callSession, true),
      ),
    );
  }

  void _rejectCall(BuildContext context, CallSession callSession) {
    callSession.reject();
  }

  Future<bool> _onBackPressed(BuildContext context) {
    return Future.value(false);
  }
}

class ConversationCallScreen extends StatefulWidget {
  final CallSession _callSession;
  final bool _isIncoming;

  @override
  State<StatefulWidget> createState() {
    return _ConversationCallScreenState(_callSession, _isIncoming);
  }

  ConversationCallScreen(this._callSession, this._isIncoming);
}

class _ConversationCallScreenState extends State<ConversationCallScreen> {
  static const String TAG = "_ConversationCallScreenState";
  CallSession _callSession;
  bool _isIncoming;
  bool _isCameraEnabled = true;
  bool _isSpeakerEnabled = true;
  bool _isMicMute = false;

  Map<int, RTCVideoRenderer> streams = {};

  _ConversationCallScreenState(this._callSession, this._isIncoming);

  @override
  void initState() {
    super.initState();

    _callSession.onLocalStreamReceived = _addLocalMediaStream;
    _callSession.onRemoteStreamRemoved = _removeMediaStream;
    _callSession.onRemoteStreamReceived = _addRemoteMediaStream;
    _callSession.onSessionClosed = _onSessionClosed;

    if (_isIncoming) {
      _callSession.acceptCall();
    } else {
      _callSession.startCall();
    }
  }

  void _addLocalMediaStream(MediaStream stream) {
    log("_addLocalMediaStream", TAG);
    _onStreamAdd(CubeChatConnection.instance.currentUser.id, stream);
  }

  void _addRemoteMediaStream(session, int userId, MediaStream stream) {
    log("_addRemoteMediaStream for user $userId", TAG);
    _onStreamAdd(userId, stream);
  }

  void _removeMediaStream(callSession, int userId, MediaStream stream) {
    log("_removeMediaStream for user $userId", TAG);
    RTCVideoRenderer videoRenderer = streams[userId];
    if (videoRenderer == null) return;

    videoRenderer.srcObject = null;
    videoRenderer.dispose();

    setState(() {
      streams.remove(userId);
    });
  }

  void _onSessionClosed(session) {
    log("_onSessionClosed", TAG);

    streams.forEach((opponentId, stream) {
      stream.dispose();
    });

    Navigator.pop(context);
  }

  void _onStreamAdd(int opponentId, MediaStream stream) async {
    log("_onStreamAdd for user $opponentId", TAG);

    RTCVideoRenderer streamRender = RTCVideoRenderer();
    await streamRender.initialize();
    streamRender.srcObject = stream;
    streamRender.objectFit = RTCVideoViewObjectFit.RTCVideoViewObjectFitCover;
    streamRender.mirror = true;
    setState(() => streams[opponentId] = streamRender);
  }

  List<Widget> renderStreamsGrid(Orientation orientation) {
    List<Widget> streamsExpanded = streams.entries
        .map(
          (entry) => Expanded(
            child: RTCVideoView(entry.value),
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
                            _callSession.opponentsIds.join(", "),
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
    _callSession.hungUp();
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
}
