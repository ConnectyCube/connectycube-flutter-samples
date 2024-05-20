import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:p2p_call_sample/src/utils/configs.dart';
import 'package:universal_io/io.dart';
import 'package:web_browser_detect/web_browser_detect.dart';

import 'package:connectycube_sdk/connectycube_sdk.dart';

import 'login_screen.dart';
import 'managers/call_manager.dart';
import 'utils/platform_utils.dart';

class ConversationCallScreen extends StatefulWidget {
  final P2PSession callSession;
  final bool isIncoming;

  @override
  State<StatefulWidget> createState() {
    return _ConversationCallScreenState();
  }

  const ConversationCallScreen(this.callSession, this.isIncoming, {Key? key})
      : super(key: key);
}

class _ConversationCallScreenState extends State<ConversationCallScreen>
    implements RTCSessionStateCallback<P2PSession> {
  static const String tag = "_ConversationCallScreenState";

  // final P2PSession _callSession;
  // final bool _isIncoming;
  final CubeStatsReportsManager _statsReportsManager =
      CubeStatsReportsManager();
  bool _isCameraEnabled = true;
  bool _isSpeakerEnabled = Platform.isIOS ? false : true;
  bool _isMicMute = false;
  bool _isFrontCameraUsed = true;
  final int _currentUserId = CubeChatConnection.instance.currentUser!.id!;

  MapEntry<int, RTCVideoRenderer>? primaryRenderer;
  Map<int, RTCVideoRenderer> minorRenderers = {};
  RTCVideoViewObjectFit primaryVideoFit =
      RTCVideoViewObjectFit.RTCVideoViewObjectFitCover;

  bool _enableScreenSharing = true;

  @override
  void initState() {
    super.initState();

    _enableScreenSharing = !widget.callSession.startScreenSharing;

    _initAlreadyReceivedStreams();

    widget.callSession.onLocalStreamReceived = _addLocalMediaStream;
    widget.callSession.onRemoteStreamReceived = _addRemoteMediaStream;
    widget.callSession.onSessionClosed = _onSessionClosed;
    _statsReportsManager.init(widget.callSession);
    widget.callSession.setSessionCallbacksListener(this);

    if (widget.isIncoming) {
      if (widget.callSession.state == RTCSessionState.RTC_SESSION_NEW) {
        widget.callSession.acceptCall();
      }
    } else {
      widget.callSession.startCall();
    }

    CallManager.instance.onMicMuted = (muted, sessionId) {
      setState(() {
        _isMicMute = muted;
        widget.callSession.setMicrophoneMute(_isMicMute);
      });
    };
  }

  @override
  void dispose() {
    super.dispose();

    stopBackgroundExecution();

    primaryRenderer?.value.srcObject = null;
    primaryRenderer?.value.dispose();

    minorRenderers.forEach((opponentId, renderer) {
      log("[dispose] dispose renderer for $opponentId", tag);
      try {
        renderer.srcObject?.dispose();
        renderer.srcObject = null;
        renderer.dispose();
      } catch (e) {
        log('Error $e');
      }
    });
  }

  Future<void> _addLocalMediaStream(MediaStream stream) async {
    log("_addLocalMediaStream, stream Id: ${stream.id}", tag);

    _addMediaStream(_currentUserId, stream);
  }

  void _addRemoteMediaStream(session, int userId, MediaStream stream) {
    log("_addRemoteMediaStream for user $userId", tag);

    _addMediaStream(userId, stream);
  }

  Future<void> _removeMediaStream(callSession, int userId) async {
    log("_removeMediaStream for user $userId", tag);
    var videoRenderer = minorRenderers[userId];
    if (videoRenderer == null) return;

    videoRenderer.srcObject = null;
    videoRenderer.dispose();

    setState(() {
      minorRenderers.remove(userId);
    });
  }

  Future<void> _addMediaStream(int userId, MediaStream stream) async {
    if (primaryRenderer == null) {
      primaryRenderer = MapEntry(userId, RTCVideoRenderer());
      await primaryRenderer!.value.initialize();

      setState(() {
        primaryRenderer?.value.srcObject = stream;
      });

      return;
    }

    if (minorRenderers[userId] == null) {
      minorRenderers[userId] = RTCVideoRenderer();
      await minorRenderers[userId]?.initialize();
    }

    setState(() {
      minorRenderers[userId]?.srcObject = stream;

      if (primaryRenderer?.key == _currentUserId ||
          primaryRenderer?.key == userId) {
        _replacePrimaryRenderer(userId);
      }
    });
  }

  void _replacePrimaryRenderer(int newPrimaryUser) {
    if (primaryRenderer?.key != newPrimaryUser) {
      minorRenderers.addEntries([primaryRenderer!]);
    }

    primaryRenderer =
        MapEntry(newPrimaryUser, minorRenderers.remove(newPrimaryUser)!);
  }

  void _onSessionClosed(session) {
    log("_onSessionClosed", tag);
    widget.callSession.removeSessionCallbacksListener();

    _statsReportsManager.dispose();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const LoginScreen(),
      ),
    );
  }

  Widget buildMinorVideoItem(int opponentId, RTCVideoRenderer renderer) {
    return Expanded(
      child: Stack(
        children: [
          RTCVideoView(
            renderer,
            objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
            mirror: false,
          ),
          Align(
              alignment: Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.all(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                  ),
                  child: RotatedBox(
                    quarterTurns: -1,
                    child: StreamBuilder<CubeMicLevelEvent>(
                      stream: _statsReportsManager.micLevelStream
                          .where((event) => event.userId == opponentId),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const LinearProgressIndicator(value: 0);
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
                margin: const EdgeInsets.only(top: 8),
                child: ClipRRect(
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    color: Colors.black26,
                    child: StreamBuilder<CubeVideoBitrateEvent>(
                      stream: _statsReportsManager.videoBitrateStream
                          .where((event) => event.userId == opponentId),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Text(
                            '0 kbits/sec',
                            style: TextStyle(color: Colors.white),
                          );
                        } else {
                          var videoBitrateForUser = snapshot.data!;
                          return Text(
                            '${videoBitrateForUser.bitRate} kbits/sec',
                            style: const TextStyle(color: Colors.white),
                          );
                        }
                      },
                    ),
                  ),
                ),
              ))
        ],
      ),
    );
  }

  List<Widget> renderStreamsGrid(Orientation orientation) {
    List<Widget> streamsExpanded = [];

    if (primaryRenderer != null) {
      streamsExpanded.add(Expanded(
          child: RTCVideoView(
        primaryRenderer!.value,
        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
        mirror: true,
      )));
    }

    if (CallManager.instance.remoteStreams.isNotEmpty) {
      minorRenderers.addEntries([
        ...CallManager.instance.remoteStreams.entries.map((mediaStreamEntry) {
          var videoRenderer = RTCVideoRenderer();
          videoRenderer.initialize().then((value) {
            videoRenderer.srcObject = mediaStreamEntry.value;
          });

          return MapEntry(mediaStreamEntry.key, videoRenderer);
        })
      ]);
      CallManager.instance.remoteStreams.clear();
    }

    streamsExpanded.addAll(minorRenderers.entries
        .map(
          (entry) => buildMinorVideoItem(entry.key, entry.value),
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
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.grey,
        body: Stack(fit: StackFit.loose, clipBehavior: Clip.none, children: [
          _isVideoCall()
              ? OrientationBuilder(
                  builder: (context, orientation) {
                    return widget.callSession.opponentsIds.length > 1
                        ? _buildGroupCallLayout(orientation)
                        : _buildPrivateCallLayout(orientation);
                  },
                )
              : Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Padding(
                        padding: EdgeInsets.only(bottom: 24),
                        child: Text(
                          "Audio call",
                          style: TextStyle(fontSize: 28),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: Text(
                          "Members:",
                          style: TextStyle(
                              fontSize: 20, fontStyle: FontStyle.italic),
                        ),
                      ),
                      Text(
                        widget.callSession.opponentsIds.join(", "),
                        style: const TextStyle(fontSize: 20),
                      ),
                    ],
                  ),
                ),
          Align(
            alignment: Alignment.bottomCenter,
            child: _getActionsPanel(),
          ),
        ]),
      ),
    );
  }

  Widget _buildGroupCallLayout(Orientation orientation) {
    return Center(
      child: Container(
        child: orientation == Orientation.portrait
            ? Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: renderGroupCallViews(orientation))
            : Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: renderGroupCallViews(orientation)),
      ),
    );
  }

  Widget _buildPrivateCallLayout(Orientation orientation) {
    return Stack(children: [
      if (primaryRenderer != null) _buildPrimaryVideoView(orientation),
      if (minorRenderers.isNotEmpty)
        Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: orientation == Orientation.portrait
                  ? EdgeInsets.only(
                      top: MediaQuery.of(context).padding.top + 10,
                      right: MediaQuery.of(context).padding.right + 10)
                  : EdgeInsets.only(
                      right: MediaQuery.of(context).padding.right + 10,
                      top: MediaQuery.of(context).padding.top + 10),
              child: buildItems(
                      minorRenderers,
                      orientation == Orientation.portrait
                          ? MediaQuery.of(context).size.width / 3
                          : MediaQuery.of(context).size.width / 4,
                      orientation == Orientation.portrait
                          ? MediaQuery.of(context).size.height / 4
                          : MediaQuery.of(context).size.height / 2.5)
                  .first,
            ))
    ]);
  }

  List<Widget> renderGroupCallViews(Orientation orientation) {
    List<Widget> streamsExpanded = [];

    if (primaryRenderer != null) {
      streamsExpanded.add(
        Expanded(flex: 3, child: _buildPrimaryVideoView(orientation)),
      );
    }

    double itemHeight;
    double itemWidth;

    if (orientation == Orientation.portrait) {
      itemHeight = MediaQuery.of(context).size.height / 3 * 0.8;
      itemWidth = itemHeight / 3 * 4;
    } else {
      itemWidth = MediaQuery.of(context).size.width / 3 * 0.8;
      itemHeight = itemWidth / 4 * 3;
    }

    var minorItems = buildItems(minorRenderers, itemWidth, itemHeight);

    if (minorRenderers.isNotEmpty) {
      var membersList = Expanded(
        flex: 1,
        child: ListView(
          scrollDirection: orientation == Orientation.landscape
              ? Axis.vertical
              : Axis.horizontal,
          children: minorItems,
        ),
      );

      streamsExpanded.add(membersList);
    }

    return streamsExpanded;
  }

  List<Widget> buildItems(Map<int, RTCVideoRenderer> renderers,
      double itemWidth, double itemHeight) {
    return renderers.entries
        .map(
          (entry) => GestureDetector(
            onTap: () {
              setState(() {
                _replacePrimaryRenderer(entry.key);
              });
            },
            child: AbsorbPointer(
              child: Container(
                width: itemWidth,
                height: itemHeight,
                padding: const EdgeInsets.all(4),
                child: Stack(
                  children: [
                    StreamBuilder<CubeMicLevelEvent>(
                      stream: _statsReportsManager.micLevelStream
                          .where((event) => event.userId == entry.key),
                      builder: (context, snapshot) {
                        var width =
                            !snapshot.hasData ? 0 : snapshot.data!.micLevel * 4;

                        return Container(
                          decoration: ShapeDecoration(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6.0),
                              side: BorderSide(
                                  width: width.toDouble(),
                                  color: Colors.green,
                                  strokeAlign: 1.0),
                            ),
                          ),
                        );
                      },
                    ),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6.0),
                      child: RTCVideoView(
                        entry.value,
                        objectFit:
                            RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                        mirror: entry.key == _currentUserId &&
                            _isFrontCameraUsed &&
                            _enableScreenSharing,
                      ),
                    ),
                    if (entry.key != _currentUserId)
                      Align(
                          alignment: Alignment.topCenter,
                          child: Container(
                            margin: const EdgeInsets.only(top: 8),
                            child: ClipRRect(
                              borderRadius:
                                  const BorderRadius.all(Radius.circular(12)),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                color: Colors.black26,
                                child: StreamBuilder<CubeVideoBitrateEvent>(
                                  stream: _statsReportsManager
                                      .videoBitrateStream
                                      .where(
                                          (event) => event.userId == entry.key),
                                  builder: (context, snapshot) {
                                    if (!snapshot.hasData) {
                                      return const Text(
                                        '0 kbits/sec',
                                        style: TextStyle(color: Colors.white),
                                      );
                                    } else {
                                      var videoBitrateForUser = snapshot.data!;
                                      return Text(
                                        '${videoBitrateForUser.bitRate} kbits/sec',
                                        style: const TextStyle(
                                            color: Colors.white),
                                      );
                                    }
                                  },
                                ),
                              ),
                            ),
                          )),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ClipRRect(
                          borderRadius:
                              const BorderRadius.all(Radius.circular(12)),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            color: Colors.black26,
                            child: Text(
                              entry.key ==
                                      CubeChatConnection
                                          .instance.currentUser?.id
                                  ? 'Me'
                                  : users
                                          .where((user) => user.id == entry.key)
                                          .first
                                          .fullName ??
                                      'Unknown',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        )
        .toList();
  }

  Widget _buildPrimaryVideoView(Orientation orientation) {
    return Stack(
      children: [
        RTCVideoView(
          primaryRenderer!.value,
          objectFit: primaryVideoFit,
          mirror: primaryRenderer!.key == _currentUserId &&
              _isFrontCameraUsed &&
              _enableScreenSharing,
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: StreamBuilder<CubeMicLevelEvent>(
            stream: _statsReportsManager.micLevelStream
                .where((event) => event.userId == primaryRenderer!.key),
            builder: (context, snapshot) {
              return Padding(
                  padding: EdgeInsets.only(
                      top: MediaQuery.of(context).padding.top + 50,
                      left: MediaQuery.of(context).padding.left + 15,
                      bottom: MediaQuery.of(context).padding.bottom + 100),
                  child: RotatedBox(
                    quarterTurns: -1,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 200),
                      child: LinearProgressIndicator(
                        value: !snapshot.hasData ? 0 : snapshot.data!.micLevel,
                      ),
                    ),
                  ));
            },
          ),
        ),
        Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: orientation == Orientation.portrait
                ? EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 10,
                    left: MediaQuery.of(context).padding.left + 10)
                : EdgeInsets.only(
                    left: MediaQuery.of(context).padding.left + 10,
                    top: MediaQuery.of(context).padding.top + 10),
            child: FloatingActionButton(
              elevation: 0,
              heroTag: "ToggleScreenFit",
              onPressed: () => _switchPrimaryVideoFit(),
              backgroundColor: Colors.black38,
              child: Icon(
                primaryVideoFit ==
                        RTCVideoViewObjectFit.RTCVideoViewObjectFitCover
                    ? Icons.zoom_in_map
                    : Icons.zoom_out_map,
                color: Colors.white,
              ),
            ),
          ),
        ),
        if (primaryRenderer!.key != _currentUserId)
          Align(
            alignment: Alignment.topCenter,
            child: Container(
              margin:
                  EdgeInsets.only(top: MediaQuery.of(context).padding.top + 10),
              child: ClipRRect(
                borderRadius: const BorderRadius.all(Radius.circular(12)),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  color: Colors.black26,
                  child: StreamBuilder<CubeVideoBitrateEvent>(
                    stream: _statsReportsManager.videoBitrateStream
                        .where((event) => event.userId == primaryRenderer!.key),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Text(
                          '0 kbits/sec',
                          style: TextStyle(color: Colors.white),
                        );
                      } else {
                        var videoBitrateForUser = snapshot.data!;
                        return Text(
                          '${videoBitrateForUser.bitRate} kbits/sec',
                          style: const TextStyle(color: Colors.white),
                        );
                      }
                    },
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  _switchPrimaryVideoFit() async {
    setState(() {
      primaryVideoFit =
          primaryVideoFit == RTCVideoViewObjectFit.RTCVideoViewObjectFitCover
              ? RTCVideoViewObjectFit.RTCVideoViewObjectFitContain
              : RTCVideoViewObjectFit.RTCVideoViewObjectFitCover;
    });
  }

  Widget _getActionsPanel() {
    return Container(
      margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom + 8,
          left: MediaQuery.of(context).padding.left + 8,
          right: MediaQuery.of(context).padding.right + 8),
      child: ClipRRect(
        borderRadius: BorderRadius.all(
            Radius.circular(Theme.of(context).useMaterial3 ? 16 : 32)),
        child: Container(
          padding: const EdgeInsets.all(4),
          color: Colors.black26,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: FloatingActionButton(
                  elevation: 0,
                  heroTag: "Mute",
                  onPressed: () => _muteMic(),
                  backgroundColor: Colors.black38,
                  child: Icon(
                    _isMicMute ? Icons.mic_off : Icons.mic,
                    color: _isMicMute ? Colors.grey : Colors.white,
                  ),
                ),
              ),
              Visibility(
                visible: _enableScreenSharing,
                child: Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: FloatingActionButton(
                    elevation: 0,
                    heroTag: "ToggleCamera",
                    onPressed: () => _toggleCamera(),
                    backgroundColor: Colors.black38,
                    child: Icon(
                      _isVideoEnabled() ? Icons.videocam : Icons.videocam_off,
                      color: _isVideoEnabled() ? Colors.white : Colors.grey,
                    ),
                  ),
                ),
              ),
              SpeedDial(
                heroTag: "Options",
                icon: Icons.more_vert,
                activeIcon: Icons.close,
                backgroundColor: Colors.black38,
                switchLabelPosition: true,
                foregroundColor: Colors.white,
                overlayColor: Colors.black,
                elevation: 0,
                overlayOpacity: 0.5,
                children: [
                  SpeedDialChild(
                    elevation: 0,
                    child: Icon(
                      _enableScreenSharing
                          ? Icons.screen_share
                          : Icons.stop_screen_share,
                      color: Colors.white,
                    ),
                    backgroundColor: Colors.black38,
                    foregroundColor: Colors.white,
                    label:
                        '${_enableScreenSharing ? 'Start' : 'Stop'} Screen Sharing',
                    onTap: () => _toggleScreenSharing(),
                  ),
                  SpeedDialChild(
                    elevation: 0,
                    visible: !(kIsWeb &&
                        (Browser().browserAgent == BrowserAgent.Safari ||
                            Browser().browserAgent == BrowserAgent.Firefox)),
                    child: Icon(
                      kIsWeb || WebRTC.platformIsDesktop
                          ? Icons.surround_sound
                          : _isSpeakerEnabled
                              ? Icons.volume_up
                              : Icons.volume_off,
                      color: _isSpeakerEnabled ? Colors.white : Colors.grey,
                    ),
                    backgroundColor: Colors.black38,
                    foregroundColor: Colors.white,
                    label:
                        'Switch ${kIsWeb || WebRTC.platformIsDesktop ? 'Audio output' : 'Speakerphone'}',
                    onTap: () => _switchSpeaker(),
                  ),
                  SpeedDialChild(
                    elevation: 0,
                    visible: kIsWeb || WebRTC.platformIsDesktop,
                    child: const Icon(
                      Icons.record_voice_over,
                      color: Colors.white,
                    ),
                    backgroundColor: Colors.black38,
                    foregroundColor: Colors.white,
                    label: 'Switch Audio Input device',
                    onTap: () => _switchAudioInput(),
                  ),
                  SpeedDialChild(
                    elevation: 0,
                    visible: _enableScreenSharing,
                    child: Icon(
                      Icons.cameraswitch,
                      color: _isVideoEnabled() ? Colors.white : Colors.grey,
                    ),
                    backgroundColor: Colors.black38,
                    foregroundColor: Colors.white,
                    label: 'Switch Camera',
                    onTap: () => _switchCamera(),
                  ),
                ],
              ),
              const Expanded(
                flex: 1,
                child: SizedBox(),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 0),
                child: FloatingActionButton(
                  backgroundColor: Colors.red,
                  onPressed: () => _endCall(),
                  child: const Icon(
                    Icons.call_end,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  _endCall() {
    CallManager.instance.hungUp();
  }

  _muteMic() {
    setState(() {
      _isMicMute = !_isMicMute;
      widget.callSession.setMicrophoneMute(_isMicMute);
      CallManager.instance.muteCall(widget.callSession.sessionId, _isMicMute);
    });
  }

  _switchCamera() {
    if (!_isVideoEnabled()) return;

    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      widget.callSession.switchCamera().then((isFrontCameraUsed) {
        setState(() {
          _isFrontCameraUsed = isFrontCameraUsed;
        });
      });
    } else {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return FutureBuilder<List<MediaDeviceInfo>>(
            future: widget.callSession.getCameras(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return AlertDialog(
                  content: const Text('No cameras found'),
                  actions: <Widget>[
                    TextButton(
                      style: TextButton.styleFrom(
                        textStyle: Theme.of(context).textTheme.labelLarge,
                      ),
                      child: const Text('Ok'),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    )
                  ],
                );
              } else {
                return SimpleDialog(
                  title: const Text('Select camera'),
                  children: snapshot.data?.map(
                    (mediaDeviceInfo) {
                      return SimpleDialogOption(
                        onPressed: () {
                          Navigator.pop(context, mediaDeviceInfo.deviceId);
                        },
                        child: Text(mediaDeviceInfo.label),
                      );
                    },
                  ).toList(),
                );
              }
            },
          );
        },
      ).then((deviceId) {
        log("onCameraSelected deviceId: $deviceId", tag);
        if (deviceId != null) {
          widget.callSession.switchCamera(deviceId: deviceId);
        }
      });
    }
  }

  _toggleCamera() {
    if (!_isVideoCall()) return;

    setState(() {
      _isCameraEnabled = !_isCameraEnabled;
      widget.callSession.setVideoEnabled(_isCameraEnabled);
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

    if (!mounted) return;

    var desktopCapturerSource = _enableScreenSharing && isDesktop
        ? await showDialog<DesktopCapturerSource>(
            context: context,
            builder: (context) => ScreenSelectDialog(),
          )
        : null;

    foregroundServiceFuture.then((_) {
      widget.callSession
          .enableScreenSharing(_enableScreenSharing,
              desktopCapturerSource: desktopCapturerSource,
              useIOSBroadcasting: true,
              requestAudioForScreenSharing: true)
          .then((voidResult) {
        setState(() {
          _enableScreenSharing = !_enableScreenSharing;
          _isFrontCameraUsed = _enableScreenSharing;
        });
      });
    });
  }

  bool _isVideoEnabled() {
    return _isVideoCall() && _isCameraEnabled;
  }

  bool _isVideoCall() {
    return CallType.VIDEO_CALL == widget.callSession.callType;
  }

  _switchSpeaker() {
    if (kIsWeb || WebRTC.platformIsDesktop) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return FutureBuilder<List<MediaDeviceInfo>>(
            future: widget.callSession.getAudioOutputs(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return AlertDialog(
                  content: const Text('No Audio output devices found'),
                  actions: <Widget>[
                    TextButton(
                      style: TextButton.styleFrom(
                        textStyle: Theme.of(context).textTheme.labelLarge,
                      ),
                      child: const Text('Ok'),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    )
                  ],
                );
              } else {
                return SimpleDialog(
                  title: const Text('Select Audio output device'),
                  children: snapshot.data?.map(
                    (mediaDeviceInfo) {
                      return SimpleDialogOption(
                        onPressed: () {
                          Navigator.pop(context, mediaDeviceInfo.deviceId);
                        },
                        child: Text(mediaDeviceInfo.label),
                      );
                    },
                  ).toList(),
                );
              }
            },
          );
        },
      ).then((deviceId) {
        log("onAudioOutputSelected deviceId: $deviceId", tag);
        if (deviceId != null) {
          setState(() {
            if (kIsWeb) {
              primaryRenderer?.value.audioOutput(deviceId);
              minorRenderers.forEach((userId, renderer) {
                renderer.audioOutput(deviceId);
              });
            } else {
              widget.callSession.selectAudioOutput(deviceId);
            }
          });
        }
      });
    } else {
      setState(() {
        _isSpeakerEnabled = !_isSpeakerEnabled;
        widget.callSession.enableSpeakerphone(_isSpeakerEnabled);
      });
    }
  }

  _switchAudioInput() {
    if (kIsWeb || WebRTC.platformIsDesktop) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return FutureBuilder<List<MediaDeviceInfo>>(
            future: widget.callSession.getAudioInputs(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return AlertDialog(
                  content: const Text('No Audio input devices found'),
                  actions: <Widget>[
                    TextButton(
                      style: TextButton.styleFrom(
                        textStyle: Theme.of(context).textTheme.labelLarge,
                      ),
                      child: const Text('Ok'),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    )
                  ],
                );
              } else {
                return SimpleDialog(
                  title: const Text('Select Audio input device'),
                  children: snapshot.data?.map(
                    (mediaDeviceInfo) {
                      return SimpleDialogOption(
                        onPressed: () {
                          Navigator.pop(context, mediaDeviceInfo.deviceId);
                        },
                        child: Text(mediaDeviceInfo.label),
                      );
                    },
                  ).toList(),
                );
              }
            },
          );
        },
      ).then((deviceId) {
        log("onAudioOutputSelected deviceId: $deviceId", tag);
        if (deviceId != null) {
          setState(() {
            widget.callSession.selectAudioInput(deviceId);
          });
        }
      });
    }
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

  @override
  void onConnectingToUser(P2PSession session, int userId) {
    log("onConnectingToUser userId= $userId");
  }

  @override
  void onConnectionFailedWithUser(P2PSession session, int userId) {
    log("onConnectionFailedWithUser userId= $userId");
  }

  void _initAlreadyReceivedStreams() {
    if (CallManager.instance.remoteStreams.isNotEmpty) {
      minorRenderers.addEntries([
        ...CallManager.instance.remoteStreams.entries.map((mediaStreamEntry) {
          var videoRenderer = RTCVideoRenderer();
          videoRenderer.initialize().then((value) {
            videoRenderer.srcObject = mediaStreamEntry.value;
          });

          return MapEntry(mediaStreamEntry.key, videoRenderer);
        })
      ]);
      // CallManager.instance.remoteStreams
      //     .clear(); //TODO VT check concurrency issue
    }

    createLocalRenderer() {
      var renderer = MapEntry(_currentUserId, RTCVideoRenderer());
      renderer.value.initialize().then((value) {
        renderer.value.srcObject = CallManager.instance.localMediaStream;
      });

      return renderer;
    }

    if (CallManager.instance.localMediaStream != null) {
      if (minorRenderers.isNotEmpty) {
        var tempPrimaryRenderer = minorRenderers.entries.first;
        primaryRenderer = tempPrimaryRenderer;
        minorRenderers.remove(tempPrimaryRenderer.key);
        minorRenderers.addEntries([createLocalRenderer()]);
      } else {
        primaryRenderer = createLocalRenderer();
        // CallManager.instance.localMediaStream = null;
      }
    }
  }
}
