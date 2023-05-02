import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:connectycube_sdk/connectycube_sdk.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:web_browser_detect/web_browser_detect.dart';

import 'utils/call_manager.dart';
import 'utils/configs.dart';
import 'utils/platform_utils.dart';
import 'utils/speakers_manager.dart';
import 'utils/video_config.dart';

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
        ),
      ),
    );
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

class _ConversationCallScreenState extends State<ConversationCallScreen> {
  static const String TAG = "_ConversationCallScreenState";
  final ConferenceSession _callSession;
  CallManager _callManager = CallManager.instance;
  final bool _isIncoming;
  final String _meetingId;
  final List<int> _opponents;
  final CubeStatsReportsManager _statsReportsManager =
      CubeStatsReportsManager();
  final SpeakersManager _speakersManager = SpeakersManager();

  LayoutMode layoutMode = LayoutMode.speaker;
  bool _isCameraEnabled = true;
  bool _isSpeakerEnabled = true;
  bool _isMicMute = false;
  bool _enableScreenSharing;
  bool _isFrontCameraUsed = true;
  RTCVideoViewObjectFit primaryVideoFit =
      RTCVideoViewObjectFit.RTCVideoViewObjectFitCover;
  final int currentUserId = CubeChatConnection.instance.currentUser!.id!;

  MapEntry<int, RTCVideoRenderer>? primaryRenderer;
  Map<int, RTCVideoRenderer> minorRenderers = {};

  _ConversationCallScreenState(
      this._callSession, this._meetingId, this._opponents, this._isIncoming)
      : _enableScreenSharing = !_callSession.startScreenSharing;

  @override
  void initState() {
    super.initState();
    _initCustomMediaConfigs();
    _statsReportsManager.init(_callSession);
    _speakersManager.init(_statsReportsManager, _onSpeakerChanged);
    _callManager.onReceiveRejectCall = _onReceiveRejectCall;
    _callManager.onCloseCall = _onCloseCall;

    _callSession.onLocalStreamReceived = _addLocalMediaStream;
    _callSession.onRemoteStreamTrackReceived = _addRemoteMediaStream;
    _callSession.onSessionClosed = _onSessionClosed;
    _callSession.onPublishersReceived = onPublishersReceived;
    _callSession.onPublisherLeft = onPublisherLeft;
    _callSession.onError = onError;
    _callSession.onSubStreamChanged = onSubStreamChanged;
    _callSession.onLayerChanged = onLayerChanged;

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

    _statsReportsManager.dispose();
    _speakersManager.dispose();

    stopBackgroundExecution();

    primaryRenderer?.value.srcObject = null;
    primaryRenderer?.value.dispose();

    minorRenderers.forEach((opponentId, renderer) {
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
    _callSession.setMaxBandwidth(0);

    _addMediaStream(currentUserId, true, stream);
  }

  void _addRemoteMediaStream(session, int userId, MediaStream stream,
      {String? trackId}) {
    log("_addRemoteMediaStream for user $userId", TAG);

    _addMediaStream(userId, false, stream, trackId: trackId);
  }

  void _removeMediaStream(callSession, int userId) {
    log("_removeMediaStream for user $userId", TAG);
    RTCVideoRenderer? videoRenderer = minorRenderers[userId];
    if (videoRenderer != null) {
      videoRenderer.srcObject = null;
      videoRenderer.dispose();

      setState(() {
        minorRenderers.remove(userId);
      });
    } else if (primaryRenderer?.key == userId) {
      var rendererToRemove = primaryRenderer?.value;

      if (rendererToRemove != null) {
        rendererToRemove.srcObject = null;
        rendererToRemove.dispose();
      }

      if (minorRenderers.isNotEmpty) {
        setState(() {
          var userIdToRemoveRenderer = minorRenderers.keys.firstWhere(
              (key) => key != currentUserId,
              orElse: () => minorRenderers.keys.first);

          primaryRenderer = MapEntry(userIdToRemoveRenderer,
              minorRenderers.remove(userIdToRemoveRenderer)!);
          _chooseOpponentsStreamsQuality(
              {userIdToRemoveRenderer: StreamType.high});
        });
      }
    }
  }

  void _closeSessionIfLast() {
    if (_callSession.allActivePublishers.length < 1) {
      _callManager.stopCall();
      _callSession.leave();
    }
  }

  void _onSessionClosed(session) {
    log("_onSessionClosed", TAG);
    _statsReportsManager.dispose();
    Navigator.pop(context);
  }

  void onPublishersReceived(publishers) {
    log("onPublishersReceived", TAG);
    handlePublisherReceived(publishers);
  }

  void onPublisherLeft(publisher) {
    log("onPublisherLeft $publisher", TAG);
    _removeMediaStream(_callSession, publisher);
    _closeSessionIfLast();
  }

  void onError(ex) {
    log("onError $ex", TAG);
  }

  void onSubStreamChanged(int userId, StreamType streamType) {
    log("onSubStreamChanged userId: $userId, streamType: $streamType", TAG);
  }

  void onLayerChanged(int userId, int layer) {
    log("onLayerChanged userId: $userId, layer: $layer", TAG);
  }

  void _addMediaStream(int userId, bool isLocalStream, MediaStream stream,
      {String? trackId}) async {
    log("_addMediaStream for user $userId", TAG);
    if (primaryRenderer == null || primaryRenderer!.key == currentUserId) {
      if (primaryRenderer == null) {
        primaryRenderer = MapEntry(userId, RTCVideoRenderer());
        await primaryRenderer!.value.initialize();

        setState(() {
          _setSourceForRenderer(primaryRenderer!.value, stream, isLocalStream,
              trackId: trackId);
        });
      } else {
        var newRender = RTCVideoRenderer();
        await newRender.initialize();

        _setSourceForRenderer(newRender, stream, isLocalStream,
            trackId: trackId);

        setState(() {
          minorRenderers.addEntries([primaryRenderer!]);

          primaryRenderer = MapEntry(userId, newRender);
        });
      }

      _chooseOpponentsStreamsQuality({primaryRenderer!.key: StreamType.high});
    } else {
      var newRender = primaryRenderer?.value;

      if (newRender != null && userId == primaryRenderer?.key) {
        _setSourceForRenderer(newRender, stream, isLocalStream,
            trackId: trackId);

        return;
      }

      newRender = minorRenderers[userId];

      if (newRender == null) {
        newRender = RTCVideoRenderer();
        await newRender.initialize();
      }

      _setSourceForRenderer(newRender, stream, isLocalStream, trackId: trackId);

      if (!minorRenderers.containsKey(userId)) {
        _chooseOpponentsStreamsQuality({userId: StreamType.low});

        setState(() {
          minorRenderers[userId] = newRender!;
        });
      }
    }
  }

  _setSourceForRenderer(
      RTCVideoRenderer renderer, MediaStream stream, bool isLocalStream,
      {String? trackId}) {
    isLocalStream
        ? renderer.srcObject = stream
        : renderer.setSrcObject(stream: stream, trackId: trackId);
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

  List<Widget> renderSpeakerModeViews(Orientation orientation) {
    List<Widget> streamsExpanded = [];

    if (primaryRenderer != null) {
      streamsExpanded.add(
        Expanded(
          flex: 3,
          child: Stack(
            children: [
              RTCVideoView(
                primaryRenderer!.value,
                objectFit: primaryVideoFit,
                mirror: primaryRenderer!.key == currentUserId &&
                    _isFrontCameraUsed &&
                    _enableScreenSharing,
              ),
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: orientation == Orientation.portrait
                      ? EdgeInsets.only(top: 40, right: 20)
                      : EdgeInsets.only(right: 20, top: 20),
                  child: FloatingActionButton(
                    elevation: 0,
                    heroTag: "ToggleScreenFit",
                    child: Icon(
                      primaryVideoFit ==
                              RTCVideoViewObjectFit.RTCVideoViewObjectFitCover
                          ? Icons.zoom_in_map
                          : Icons.zoom_out_map,
                      color: Colors.white,
                    ),
                    onPressed: () => _switchPrimaryVideoFit(),
                    backgroundColor: Colors.black38,
                  ),
                ),
              ),
              if (primaryRenderer!.key != currentUserId)
                Align(
                  alignment: Alignment.topCenter,
                  child: Container(
                    margin: EdgeInsets.only(
                        top: MediaQuery.of(context).padding.top + 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                      child: Container(
                        padding: EdgeInsets.all(6),
                        color: Colors.black26,
                        child: StreamBuilder<CubeVideoBitrateEvent>(
                          stream: _statsReportsManager.videoBitrateStream.where(
                              (event) => event.userId == primaryRenderer!.key),
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
                  ),
                ),
            ],
          ),
        ),
      );
    }

    var itemHeight;
    var itemWidth;

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

  void _updatePrimaryUser(int userId, bool force) {
    if (userId == primaryRenderer!.key ||
        (userId == currentUserId && !force) ||
        layoutMode == LayoutMode.grid) return;

    _chooseOpponentsStreamsQuality({
      userId: StreamType.high,
      primaryRenderer!.key: StreamType.low,
    });

    setState(() {
      minorRenderers.addEntries([primaryRenderer!]);
      primaryRenderer =
          minorRenderers.entries.where((entry) => entry.key == userId).first;
      minorRenderers.remove(userId);
    });
  }

  void _onSpeakerChanged(int userId) {
    if (userId == currentUserId) return;

    _updatePrimaryUser(userId, false);
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () => _onBackPressed(context),
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: Colors.grey,
            body: _isVideoCall()
                ? OrientationBuilder(
                    builder: (context, orientation) {
                      return layoutMode == LayoutMode.speaker
                          ? _buildSpeakerModLayout(orientation)
                          : _buildGridModLayout(orientation);
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
                  ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: _getActionsPanel(),
          ),
          OrientationBuilder(
            builder: (context, orientation) {
              return Align(
                alignment: Alignment.topLeft,
                child: Container(
                  margin: orientation == Orientation.portrait
                      ? EdgeInsets.only(top: 40, left: 20)
                      : EdgeInsets.only(left: 40, top: 20),
                  child: FloatingActionButton(
                    elevation: 0,
                    heroTag: "ToggleScreenMode",
                    child: Icon(
                      layoutMode == LayoutMode.speaker
                          ? Icons.grid_view_rounded
                          : Icons.view_sidebar_rounded,
                      color: Colors.white,
                    ),
                    onPressed: () => _switchLayoutMode(),
                    backgroundColor: Colors.black38,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  _switchLayoutMode() {
    setState(() {
      layoutMode = layoutMode == LayoutMode.speaker
          ? LayoutMode.grid
          : LayoutMode.speaker;

      var config;
      if (layoutMode == LayoutMode.grid) {
        config = Map.fromEntries(minorRenderers
            .map((key, value) => MapEntry(key, StreamType.medium))
            .entries);
        config.addEntries([MapEntry(primaryRenderer!.key, StreamType.medium)]);
      } else {
        config = Map.fromEntries(minorRenderers
            .map((key, value) => MapEntry(key, StreamType.low))
            .entries);
        config.addEntries([MapEntry(primaryRenderer!.key, StreamType.high)]);
      }

      _chooseOpponentsStreamsQuality(config);
    });
  }

  Widget _buildSpeakerModLayout(Orientation orientation) {
    return Center(
      child: Container(
        child: orientation == Orientation.portrait
            ? Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: renderSpeakerModeViews(orientation))
            : Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: renderSpeakerModeViews(orientation)),
      ),
    );
  }

  Widget _buildGridModLayout(Orientation orientation) {
    return Container(
      margin: MediaQuery.of(context).padding,
      child: GridView(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: orientation == Orientation.portrait ? 2 : 4,
          crossAxisSpacing: 0,
          mainAxisSpacing: 0,
          childAspectRatio: 4 / 3,
        ),
        padding: EdgeInsets.all(8),
        scrollDirection: Axis.vertical,
        children: _buildGridItems(orientation),
      ),
    );
  }

  List<Widget> _buildGridItems(Orientation orientation) {
    Map<int, RTCVideoRenderer> allRenderers =
        Map.fromEntries([...minorRenderers.entries]);
    if (primaryRenderer != null) {
      allRenderers.addEntries([primaryRenderer!]);
    }
    var itemHeight;
    var itemWidth;

    if (orientation == Orientation.portrait) {
      itemWidth = MediaQuery.of(context).size.width * 0.95 / 2;
      itemHeight = itemWidth / 4 * 3;
    } else {
      itemWidth = MediaQuery.of(context).size.width * 0.95 / 2;
      itemHeight = itemWidth / 4 * 3;
    }

    return buildItems(allRenderers, itemWidth, itemHeight);
  }

  List<Widget> buildItems(Map<int, RTCVideoRenderer> renderers,
      double itemWidth, double itemHeight) {
    return renderers.entries
        .map(
          (entry) => GestureDetector(
            onDoubleTap: () => _updatePrimaryUser(entry.key, true),
            child: SizedBox(
              width: itemWidth,
              height: itemHeight,
              child: Padding(
                padding: EdgeInsets.all(4),
                child: Stack(
                  children: [
                    Container(
                      margin: EdgeInsets.all(4),
                      decoration: ShapeDecoration(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(2.0),
                          side: BorderSide(
                            width: 4,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                      child: Stack(
                        children: [
                          StreamBuilder<CubeMicLevelEvent>(
                            stream: _statsReportsManager.micLevelStream
                                .where((event) => event.userId == entry.key),
                            builder: (context, snapshot) {
                              var width = !snapshot.hasData
                                  ? 0
                                  : snapshot.data!.micLevel * 4;

                              return Container(
                                decoration: ShapeDecoration(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(2.0),
                                    side: BorderSide(
                                        width: width.toDouble(),
                                        color: Colors.green,
                                        strokeAlign: 1.0),
                                  ),
                                ),
                              );
                            },
                          ),
                          RTCVideoView(
                            entry.value,
                            objectFit: RTCVideoViewObjectFit
                                .RTCVideoViewObjectFitCover,
                            mirror: entry.key == currentUserId &&
                                _isFrontCameraUsed &&
                                _enableScreenSharing,
                          ),
                        ],
                      ),
                    ),
                    if (entry.key != currentUserId)
                      Align(
                          alignment: Alignment.topCenter,
                          child: Container(
                            margin: EdgeInsets.only(top: 8),
                            child: ClipRRect(
                              borderRadius:
                                  BorderRadius.all(Radius.circular(12)),
                              child: Container(
                                padding: EdgeInsets.all(6),
                                color: Colors.black26,
                                child: StreamBuilder<CubeVideoBitrateEvent>(
                                  stream: _statsReportsManager
                                      .videoBitrateStream
                                      .where(
                                          (event) => event.userId == entry.key),
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
                          )),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        margin: EdgeInsets.only(bottom: 8),
                        child: ClipRRect(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                          child: Container(
                            padding: EdgeInsets.all(6),
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
                              style: TextStyle(color: Colors.white),
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
                    _isMicMute ? Icons.mic_off : Icons.mic,
                    color: _isMicMute ? Colors.grey : Colors.white,
                  ),
                  onPressed: () => _muteMic(),
                  backgroundColor: Colors.black38,
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
                      _isVideoEnabled() ? Icons.videocam : Icons.videocam_off,
                      color: _isVideoEnabled() ? Colors.white : Colors.grey,
                    ),
                    onPressed: () => _toggleCamera(),
                    backgroundColor: Colors.black38,
                  ),
                ),
              ),
              SpeedDial(
                heroTag: "Options",
                icon: Icons.more_vert,
                activeIcon: Icons.close,
                backgroundColor: Colors.black38,
                switchLabelPosition: true,
                overlayColor: Colors.black,
                elevation: 0,
                overlayOpacity: 0.5,
                children: [
                  SpeedDialChild(
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
                    visible: kIsWeb || WebRTC.platformIsDesktop,
                    child: Icon(
                      Icons.record_voice_over,
                      color: Colors.white,
                    ),
                    backgroundColor: Colors.black38,
                    foregroundColor: Colors.white,
                    label: 'Switch Audio Input device',
                    onTap: () => _switchAudioInput(),
                  ),
                  SpeedDialChild(
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

  _chooseOpponentsStreamsQuality(Map<int, StreamType> config) {
    config.remove(currentUserId);

    if (config.isEmpty) return;

    _callSession.requestPreferredStreamsForOpponents(config);
  }

  _muteMic() {
    setState(() {
      _isMicMute = !_isMicMute;
      _callSession.setMicrophoneMute(_isMicMute);
    });
  }

  _switchCamera() {
    if (!_isVideoEnabled()) return;

    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      _callSession.switchCamera().then((isFrontCameraUsed) {
        setState(() {
          _isFrontCameraUsed = isFrontCameraUsed;
        });
      });
    } else {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return FutureBuilder<List<MediaDeviceInfo>>(
            future: _callSession.getCameras(),
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
        log("onCameraSelected deviceId: $deviceId", TAG);
        if (deviceId != null) _callSession.switchCamera(deviceId: deviceId);
      });
    }
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

  _switchPrimaryVideoFit() async {
    setState(() {
      primaryVideoFit =
          primaryVideoFit == RTCVideoViewObjectFit.RTCVideoViewObjectFitCover
              ? RTCVideoViewObjectFit.RTCVideoViewObjectFitContain
              : RTCVideoViewObjectFit.RTCVideoViewObjectFitCover;
    });
  }

  bool _isVideoEnabled() {
    return _isVideoCall() && _isCameraEnabled;
  }

  bool _isVideoCall() {
    return CallType.VIDEO_CALL == _callSession.callType;
  }

  _switchSpeaker() {
    if (kIsWeb || WebRTC.platformIsDesktop) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return FutureBuilder<List<MediaDeviceInfo>>(
            future: _callSession.getAudioOutputs(),
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
        log("onAudioOutputSelected deviceId: $deviceId", TAG);
        if (deviceId != null) {
          setState(() {
            if (kIsWeb) {
              primaryRenderer?.value.audioOutput(deviceId);
              minorRenderers.forEach((userId, renderer) {
                renderer.audioOutput(deviceId);
              });
            } else {
              _callSession.selectAudioOutput(deviceId);
            }
          });
        }
      });
    } else {
      setState(() {
        _isSpeakerEnabled = !_isSpeakerEnabled;
        _callSession.enableSpeakerphone(_isSpeakerEnabled);
      });
    }
  }

  _switchAudioInput() {
    if (kIsWeb || WebRTC.platformIsDesktop) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return FutureBuilder<List<MediaDeviceInfo>>(
            future: _callSession.getAudioInputs(),
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
        log("onAudioOutputSelected deviceId: $deviceId", TAG);
        if (deviceId != null) {
          setState(() {
            _callSession.selectAudioInput(deviceId);
          });
        }
      });
    }
  }

  void _initCustomMediaConfigs() {
    RTCMediaConfig mediaConfig = RTCMediaConfig.instance;
    mediaConfig.minHeight = HD_VIDEO.height;
    mediaConfig.minWidth = HD_VIDEO.width;
  }
}

enum LayoutMode { speaker, grid }
