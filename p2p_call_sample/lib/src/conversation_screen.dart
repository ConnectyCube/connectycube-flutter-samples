import 'dart:typed_data';

import 'package:connectycube_sdk/connectycube_sdk.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:universal_io/io.dart';
import 'package:url_launcher/url_launcher.dart';

import 'login_screen.dart';
import 'managers/call_manager.dart';

class ConversationCallScreen extends StatefulWidget {
  final P2PSession _callSession;
  final bool _isIncoming;

  @override
  State<StatefulWidget> createState() {
    return _ConversationCallScreenState(_callSession, _isIncoming);
  }

  ConversationCallScreen(this._callSession, this._isIncoming);
}

class _ConversationCallScreenState extends State<ConversationCallScreen>
    implements RTCSessionStateCallback<P2PSession> {
  static const String TAG = "_ConversationCallScreenState";
  final P2PSession _callSession;
  final bool _isIncoming;
  bool _isCameraEnabled = true;
  bool _isSpeakerEnabled = true;
  bool _isMicMute = false;
  bool _isTorchEnabled = false;

  RTCVideoRenderer? localRenderer;
  Map<int, RTCVideoRenderer> remoteRenderers = {};

  bool _enableScreenSharing;

  _ConversationCallScreenState(this._callSession, this._isIncoming)
      : _enableScreenSharing = !_callSession.startScreenSharing;

  @override
  void initState() {
    super.initState();

    // localRenderer = RTCVideoRenderer();
    // localRenderer!.initialize();

    _callSession.onLocalStreamReceived = _addLocalMediaStream;
    _callSession.onRemoteStreamReceived = _addRemoteMediaStream;
    _callSession.onSessionClosed = _onSessionClosed;

    _callSession.setSessionCallbacksListener(this);
    if (_isIncoming) {
      _callSession.acceptCall();
    } else {
      _callSession.startCall();
    }
  }

  @override
  Future<void> dispose() async {
    super.dispose();

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

  Future<void> _addLocalMediaStream(MediaStream stream) async {
    log("_addLocalMediaStream", TAG);
    if (localRenderer == null) {
      localRenderer = RTCVideoRenderer();
      await localRenderer!.initialize();
    }

    log('localStream getAudioTracks ${stream.getAudioTracks().length}');
    log('localStream getVideoTracks ${stream.getVideoTracks().length}');
    log('localStream id ${stream.getVideoTracks()[0].id}');
    log('localStream kind ${stream.getVideoTracks()[0].kind}');
    log('localStream label ${stream.getVideoTracks()[0].label}');
    log('localStream enabled ${stream.getVideoTracks()[0].enabled}');
    log('localStream muted ${stream.getVideoTracks()[0].muted}');


    setState(() {
      localRenderer!.srcObject = stream;
    });
  }

  void _addRemoteMediaStream(session, int userId, MediaStream stream) {
    log("_addRemoteMediaStream for user $userId", TAG);
    _onRemoteStreamAdd(userId, stream);
  }

  Future<void> _removeMediaStream(callSession, int userId) async {
    log("_removeMediaStream for user $userId", TAG);
    RTCVideoRenderer? videoRenderer = remoteRenderers[userId];
    if (videoRenderer == null) return;

    videoRenderer.srcObject = null;
    videoRenderer.dispose();

    setState(() {
      remoteRenderers.remove(userId);
    });
  }

  void _onSessionClosed(session) {
    log("_onSessionClosed", TAG);
    _callSession.removeSessionCallbacksListener();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => LoginScreen(),
      ),
    );
  }

  void _onRemoteStreamAdd(int opponentId, MediaStream stream) async {
    log("_onStreamAdd for user $opponentId", TAG);

    RTCVideoRenderer streamRender = RTCVideoRenderer();
    await streamRender.initialize();
    streamRender.srcObject = stream;
    setState(() => remoteRenderers[opponentId] = streamRender);
  }

  List<Widget> renderStreamsGrid(Orientation orientation) {
    List<Widget> streamsExpanded = [];

    if (localRenderer != null) {
      streamsExpanded.add(_buildUserVideoItem(
          CubeChatConnection.instance.currentUser!.id!, localRenderer!, true));
    }

    streamsExpanded.addAll(remoteRenderers.entries
        .map((entry) => _buildUserVideoItem(entry.key, entry.value, false))
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

  Widget _buildUserVideoItem(
      int userId, RTCVideoRenderer renderer, bool isLocalStream) {
    return Expanded(
        child: Stack(
      children: [
        RTCVideoView(
          renderer,
          objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
          mirror: isLocalStream,
        ),
        Align(
            alignment: Alignment.centerLeft,
            child: ClipRRect(
                borderRadius: BorderRadius.all(
                  Radius.circular(32),
                ),
                child: Container(
                    padding: EdgeInsets.all(4),
                    color: Colors.black26,
                    child: Column(mainAxisSize: MainAxisSize.min, children: <
                        Widget>[
                      SizedBox(
                          width: 48.0,
                          height: 48.0,
                          child: FloatingActionButton(
                            elevation: 0,
                            heroTag: "CaptureFrame",
                            child: Icon(
                              Icons.enhance_photo_translate_rounded,
                              color: Colors.white,
                            ),
                            onPressed: () async {
                              final frame =
                                  await captureFrame(renderer.srcObject!);
                              _showImageDialog(frame.asUint8List());
                            },
                            backgroundColor: Colors.black38,
                          )),
                      SizedBox(
                        width: 48.0,
                        height: 48.0,
                        child: FloatingActionButton(
                          elevation: 0,
                          heroTag: "RecordVideo",
                          child: Icon(
                            CubeMediaRecorder.instance.isRecordingNow(userId)
                                ? Icons.stop_rounded
                                : Icons.circle,
                            color: Colors.white,
                          ),
                          onPressed: () async {
                            if (CubeMediaRecorder.instance
                                .isRecordingNow(userId)) {
                              setState(() {
                                _stopRecording(userId);
                              });
                            } else {
                              setState(() {
                                _startRecording(userId, renderer.srcObject!);
                              });
                            }
                          },
                          backgroundColor: Colors.black38,
                        ),
                      ),
                      if (isLocalStream && (Platform.isAndroid || Platform.isIOS))
                        SizedBox(
                          width: 48.0,
                          height: 48.0,
                          child: FloatingActionButton(
                            elevation: 0,
                            heroTag: "ToggleTorch",
                            child: Icon(
                              _isTorchEnabled
                                  ? Icons.flash_off
                                  : Icons.flash_on,
                              color: Colors.white,
                            ),
                            onPressed: () async {
                              _callSession
                                  .setTorchEnabled(!_isTorchEnabled)
                                  .then((_) {
                                setState(() {
                                  _isTorchEnabled = !_isTorchEnabled;
                                });
                              });
                            },
                            backgroundColor: Colors.black38,
                          ),
                        ),
                    ]))))
      ],
    ));
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
              Visibility(
                visible: kIsWeb || Platform.isIOS || Platform.isAndroid,
                child: Padding(
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

  /// currently supported only Android and Web platforms
  _startRecording(int userId, MediaStream stream) async {
    var recordingPath;

    if (Platform.isAndroid) {
      var status = await Permission.manageExternalStorage.status;
      if (!status.isGranted) {
        await Permission.manageExternalStorage.request();
      }

      log('Permission.manageExternalStorage = ${await Permission.manageExternalStorage.status}');

      var storagePath = (await getExternalStorageDirectories(
                  type: StorageDirectory.movies))?[0]
              .path ??
          '';

      log('storagePath = $storagePath');

      recordingPath = storagePath + '${Platform.pathSeparator}' + '${userId}_${_callSession.sessionId}_${DateTime.now().toIso8601String()}.mp4';
    }

    CubeMediaRecorder.instance
        .startRecording(userId, stream, filePath: recordingPath);
  }

  _stopRecording(int userId) {
    CubeMediaRecorder.instance.stopRecording(userId).then((recordingResult) {
      log('recording result = $recordingResult');
      if (kIsWeb && recordingResult is String) {
        launch(recordingResult);
      }
    });
  }

  _showImageDialog(Uint8List imageBytes) async {
    await showDialog(
        context: context,
        builder: (context) => AlertDialog(
              content: Image.memory(imageBytes, height: 480, width: 480),
              actions: <Widget>[
                TextButton(
                  onPressed: Navigator.of(context, rootNavigator: true).pop,
                  child: Text('OK'),
                )
              ],
            ));
  }

  _endCall() {
    CallManager.instance.hungUp();
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

  _toggleScreenSharing() {
    _callSession.enableScreenSharing(_enableScreenSharing).then((voidResult) {
      setState(() {
        _enableScreenSharing = !_enableScreenSharing;
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

  @override
  void onConnectedToUser(P2PSession session, int userId) {
    log("onConnectedToUser userId= $userId");
  }

  @override
  void onConnectionClosedForUser(P2PSession session, int userId) {
    log("onConnectionClosedForUser userId= $userId");
    _removeMediaStream(session, userId);
  }

  @override
  void onDisconnectedFromUser(P2PSession session, int userId) {
    log("onDisconnectedFromUser userId= $userId");
  }
}
