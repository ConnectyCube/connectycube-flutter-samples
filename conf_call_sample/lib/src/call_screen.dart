import 'package:conf_call_sample/src/utils/call_manager.dart';
import 'package:conf_call_sample/src/utils/platform_utils.dart';
import 'package:conf_call_sample/src/utils/video_config.dart';
import 'package:flutter/material.dart';

import 'package:connectycube_sdk/connectycube_sdk.dart';

class IncomingCallScreen extends StatelessWidget {
  static const String TAG = "IncomingCallScreen";
  final String _meetingId;
  final List<int> _participantIds;

  IncomingCallScreen(this._meetingId, this._participantIds);

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
        .createCallSession(CubeChatConnection.instance.currentUser!.id!);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ConversationCallScreen(
            callSession, _meetingId, _participantIds, true),
      ),
    );
  }

  void _rejectCall(BuildContext context) {
    CallManager.instance.reject(_meetingId, false);
    Navigator.pop(context);
  }

  Future<bool> _onBackPressed(BuildContext context) {
    return Future.value(false);
  }
}

class ConversationCallScreen extends StatefulWidget {
  final ConferenceSession _callSession;
  final String _meetingId;
  final List<int> opponents;
  final bool _isIncoming;

  @override
  State<StatefulWidget> createState() {
    return _ConversationCallScreenState(
        _callSession, _meetingId, opponents, _isIncoming);
  }

  ConversationCallScreen(
      this._callSession, this._meetingId, this.opponents, this._isIncoming);
}

class _ConversationCallScreenState extends State<ConversationCallScreen>
    implements RTCSessionStateCallback<ConferenceSession> {
  static const String TAG = "_ConversationCallScreenState";
  final ConferenceSession _callSession;
  CallManager _callManager = CallManager.instance;
  final bool _isIncoming;
  final String _meetingId;
  final List<int> _opponents;
  final CubeStatsReportsManager _statsReportsManager =
      CubeStatsReportsManager();
  bool _isCameraEnabled = true;
  bool _isSpeakerEnabled = true;
  bool _isMicMute = false;

  RTCVideoRenderer? localRenderer;
  Map<int?, RTCVideoRenderer> remoteRenderers = {};

  bool _enableScreenSharing;

  _ConversationCallScreenState(
      this._callSession, this._meetingId, this._opponents, this._isIncoming)
      : _enableScreenSharing = !_callSession.startScreenSharing;

  @override
  void initState() {
    super.initState();
    _initCustomMediaConfigs();
    _statsReportsManager.init(_callSession);
    _callManager.onReceiveRejectCall = _onReceiveRejectCall;
    _callManager.onCloseCall = _onCloseCall;

    _callSession.onLocalStreamReceived = _addLocalMediaStream;
    _callSession.onRemoteStreamReceived = _addRemoteMediaStream;
    _callSession.onSessionClosed = _onSessionClosed;
    _callSession.onPublishersReceived = onPublishersReceived;
    _callSession.onPublisherLeft = onPublisherLeft;
    _callSession.onError = onError;

    _callSession.setSessionCallbacksListener(this);

    _callSession.joinDialog(_meetingId, ((publishers) {
      log("join session= $publishers", TAG);

      if (!_isIncoming) {
        _callManager.startCall(
            _meetingId, _opponents, _callSession.currentUserId);
      }
    }), conferenceRole: ConferenceRole.PUBLISHER);
    // }), conferenceRole: ConferenceRole.LISTENER);
  }

  @override
  void dispose() {
    super.dispose();

    stopBackgroundExecution();

    localRenderer?.srcObject = null;
    localRenderer?.dispose();

    remoteRenderers.forEach((opponentId, renderer) {
      log("[dispose] dispose renderer for $opponentId", TAG);
      try {
        renderer.srcObject = null;
        renderer.dispose();
      } catch (e) {
        log('Error $e');
      }
    });
  }

  void _onCloseCall() {
    log("_onCloseCall", TAG);
    _callSession.leave();
  }

  void _onReceiveRejectCall(String meetingId, int participantId, bool isBusy) {
    log("_onReceiveRejectCall got reject from user $participantId", TAG);
  }

  Future<void> _addLocalMediaStream(MediaStream stream) async {
    log("_addLocalMediaStream", TAG);
    if (localRenderer == null) {
      localRenderer = RTCVideoRenderer();
      await localRenderer!.initialize();
    }

    setState(() {
      localRenderer!.srcObject = stream;
    });
  }

  void _addRemoteMediaStream(session, int userId, MediaStream stream) {
    log("_addRemoteMediaStream for user $userId", TAG);
    _onRemoteStreamAdd(userId, stream);
  }

  void _removeMediaStream(callSession, int userId) {
    log("_removeMediaStream for user $userId", TAG);
    RTCVideoRenderer? videoRenderer = remoteRenderers[userId];
    if (videoRenderer == null) return;

    videoRenderer.srcObject = null;
    videoRenderer.dispose();

    setState(() {
      remoteRenderers.remove(userId);
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
    _statsReportsManager.dispose();
    _callSession.removeSessionCallbacksListener();
    (session as ConferenceSession).leave();
    Navigator.pop(context);
  }

  void onPublishersReceived(publishers) {
    log("onPublishersReceived", TAG);
    handlePublisherReceived(publishers);
  }

  void onPublisherLeft(publisherId) {
    log("onPublisherLeft $publisherId", TAG);
    _removeMediaStream(_callSession, publisherId!);
    _closeSessionIfLast();
  }

  void onError(ex) {
    log("onError $ex", TAG);
  }

  void _onRemoteStreamAdd(int opponentId, MediaStream stream) async {
    log("_onRemoteStreamAdd for user $opponentId", TAG);

    var streamRender = remoteRenderers[opponentId];

    if (streamRender == null) {
      streamRender = RTCVideoRenderer();
      await streamRender.initialize();
    }

    setState(() {
      streamRender!.srcObject = stream;
      remoteRenderers[opponentId] = streamRender;
    });
  }

  void handlePublisherReceived(List<int?> publishers) {
    if (!_isIncoming) {
      publishers.forEach((id) {
        if (id != null) {
          _callManager.handleAcceptCall(id);
        }
      });
    }
  }

  List<Widget> renderStreamsGrid(Orientation orientation) {
    List<Widget> streamsExpanded = [];

    if (localRenderer != null) {
      streamsExpanded.add(Expanded(
          child: RTCVideoView(
        localRenderer!,
        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
        mirror: true,
      )));
    }

    streamsExpanded.addAll(remoteRenderers.entries
        .map(
          (entry) => Expanded(
            child: Stack(
              children: [
                RTCVideoView(
                  entry.value,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  mirror: false,
                ),
                Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      margin: EdgeInsets.all(8),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: 10,
                        ),
                        child: RotatedBox(
                          quarterTurns: -1,
                          child: StreamBuilder<CubeMicLevelEvent>(
                            stream: _statsReportsManager.micLevelStream
                                .where((event) => event.userId == entry.key),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) {
                                return LinearProgressIndicator(value: 0);
                              } else {
                                var micLevelForUser = snapshot.data!;
                                return LinearProgressIndicator(
                                    value: micLevelForUser.micLevel);
                              }
                            },
                          ),
                        ),
                      ),
                    )),
                Align(
                    alignment: Alignment.topCenter,
                    child: Container(
                      margin: EdgeInsets.only(top: 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                        child: Container(
                          padding: EdgeInsets.all(8),
                          color: Colors.black26,
                          child: StreamBuilder<CubeVideoBitrateEvent>(
                            stream: _statsReportsManager.videoBitrateStream
                                .where((event) => event.userId == entry.key),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) {
                                return Text(
                                  '0 kbits/sec',
                                  style: TextStyle(color: Colors.white),
                                );
                              } else {
                                var videoBitrateForUser = snapshot.data!;
                                return Text(
                                  '${videoBitrateForUser.bitRate} kbits/sec',
                                  style: TextStyle(color: Colors.white),
                                );
                              }
                            },
                          ),
                        ),
                      ),
                    ))
              ],
            ),
          ),
        )
        .toList());

    if (streamsExpanded.length > 2) {
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
                  heroTag: "ToggleScreenSharing",
                  child: Icon(
                    _enableScreenSharing
                        ? Icons.screen_share
                        : Icons.stop_screen_share,
                    color: Colors.white,
                  ),
                  onPressed: () => _toggleScreenSharing(),
                  backgroundColor: Colors.black38,
                ),
              ),
              Visibility(
                visible: _enableScreenSharing,
                child: Padding(
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
              ),
              Visibility(
                visible: _enableScreenSharing,
                child: Padding(
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

  _toggleScreenSharing() async {
    var foregroundServiceFuture = _enableScreenSharing
        ? startBackgroundExecution()
        : stopBackgroundExecution();

    var hasPermissions = await hasBackgroundExecutionPermissions();

    if (!hasPermissions) {
      await initForegroundService();
    }

    var desktopCapturerSource = _enableScreenSharing && isDesktop
        ? await showDialog<DesktopCapturerSource>(
            context: context,
            builder: (context) => ScreenSelectDialog(),
          )
        : null;

    foregroundServiceFuture.then((_) {
      _callSession
          .enableScreenSharing(_enableScreenSharing,
              desktopCapturerSource: desktopCapturerSource,
              useIOSBroadcasting: true)
          .then((voidResult) {
        setState(() {
          _enableScreenSharing = !_enableScreenSharing;
        });
      });
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
    if (_opponents.length == 1) {
      mediaConfig.minHeight = HD_VIDEO.height;
      mediaConfig.minWidth = HD_VIDEO.width;
    } else if (_opponents.length <= 3) {
      mediaConfig.minHeight = VGA_VIDEO.height;
      mediaConfig.minWidth = VGA_VIDEO.width;
    } else {
      mediaConfig.minHeight = QVGA_VIDEO.height;
      mediaConfig.minWidth = QVGA_VIDEO.width;
    }
    mediaConfig.minFrameRate = 30;
  }

  @override
  void onConnectedToUser(ConferenceSession session, int? userId) {
    log("onConnectedToUser userId= $userId");
  }

  @override
  void onConnectionClosedForUser(ConferenceSession session, int? userId) {
    log("onConnectionClosedForUser userId= $userId");
  }

  @override
  void onDisconnectedFromUser(ConferenceSession session, int? userId) {
    log("onDisconnectedFromUser userId= $userId");
  }
}
