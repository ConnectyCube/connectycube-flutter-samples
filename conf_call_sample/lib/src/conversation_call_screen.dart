import 'dart:async';
import 'dart:io';

import 'package:assets_audio_player/assets_audio_player.dart';
import 'package:conf_call_sample/src/utils/duration_timer.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:connectycube_sdk/connectycube_sdk.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:web_browser_detect/web_browser_detect.dart';

import 'select_opponents_screen.dart';
import 'utils/call_manager.dart';
import 'utils/configs.dart';
import 'utils/consts.dart';
import 'utils/platform_utils.dart';
import 'utils/speakers_manager.dart';
import 'utils/string_utils.dart';

class ConversationCallScreen extends StatefulWidget {
  final CubeUser _currentUser;
  final ConferenceSession _callSession;
  final String _meetingId;
  final List<int> opponents;
  final bool _isIncoming;
  final String _callName;
  final MediaStream? initialLocalMediaStream;
  final bool isFrontCameraUsed;

  @override
  State<StatefulWidget> createState() {
    return _ConversationCallScreenState(
      _currentUser,
      _callSession,
      _meetingId,
      opponents,
      _isIncoming,
      _callName,
      initialLocalMediaStream: initialLocalMediaStream,
      isFrontCameraUsed: isFrontCameraUsed,
    );
  }

  ConversationCallScreen(this._currentUser, this._callSession, this._meetingId,
      this.opponents, this._isIncoming, this._callName,
      {this.initialLocalMediaStream, this.isFrontCameraUsed = true});
}

class _ConversationCallScreenState extends State<ConversationCallScreen> {
  static const String TAG = "_ConversationCallScreenState";
  static final LayoutMode DEFAULT_LAYOUT_MODE = LayoutMode.speaker;
  final CubeUser _currentUser;
  final ConferenceSession _callSession;
  CallManager _callManager = CallManager.instance;
  final String _callName;
  final bool _isIncoming;
  final String _meetingId;
  final List<int> _opponents;
  final CubeStatsReportsManager _statsReportsManager =
      CubeStatsReportsManager();
  final SpeakersManager _speakersManager = SpeakersManager();
  MediaStream? initialLocalMediaStream;

  LayoutMode layoutMode = DEFAULT_LAYOUT_MODE;
  String _callStatus = 'Waiting...';
  bool _isCameraEnabled = true;
  bool _isSpeakerEnabled = true;
  bool _isMicMute = false;
  bool _enableScreenSharing;
  bool _isFrontCameraUsed = true;
  RTCVideoViewObjectFit primaryVideoFit =
      RTCVideoViewObjectFit.RTCVideoViewObjectFitCover;
  final int currentUserId;
  DurationTimer _callTimer = DurationTimer();

  MapEntry<int, RTCVideoRenderer>? primaryRenderer;
  Map<int, RTCVideoRenderer> minorRenderers = {};
  Map<int, Map<String, bool>> participantsMediaConfigs = {};
  bool _primaryUserForciblySelected = false;
  Offset _minorWidgetOffset = Offset(0, 0);
  WidgetPosition _minorWidgetPosition = WidgetPosition.topRight;
  bool _isWidgetMoving = false;

  AssetsAudioPlayer _ringtonePlayer = AssetsAudioPlayer.newPlayer();


  _ConversationCallScreenState(this._currentUser, this._callSession,
      this._meetingId, this._opponents, this._isIncoming, this._callName,
      {this.initialLocalMediaStream, bool isFrontCameraUsed = true})
      : _enableScreenSharing = !_callSession.startScreenSharing,
        _isCameraEnabled = _callSession.callType == CallType.VIDEO_CALL,
        currentUserId = _currentUser.id!,
        _isFrontCameraUsed = isFrontCameraUsed {
    if (_opponents.length == 1) {
      layoutMode = LayoutMode.private;
    }

    if (initialLocalMediaStream != null) {
      _isMicMute =
          !(initialLocalMediaStream?.getAudioTracks().firstOrNull?.enabled ??
              false);
      _isCameraEnabled =
          initialLocalMediaStream?.getVideoTracks().firstOrNull?.enabled ??
              false;
    }

    participantsMediaConfigs[currentUserId] = {
      PARAM_IS_MIC_ENABLED: !_isMicMute,
      PARAM_IS_CAMERA_ENABLED: _isCameraEnabled
    };
  }

  @override
  void initState() {
    super.initState();
    _statsReportsManager.init(_callSession);
    _speakersManager.init(_statsReportsManager, _onSpeakerChanged);

    _callManager.onReceiveRejectCall = _onReceiveRejectCall;
    _callManager.onReceiveAcceptCall = _onReceiveAcceptCall;
    _callManager.onCloseCall = _onCloseCall;
    _callManager.onCallMuted = _onCallMuted;
    _callManager.getMediaState = _getMediaState;
    _callManager.onParticipantMediaUpdated = _onParticipantMediaUpdated;

    _callSession.onLocalStreamReceived = _addLocalMediaStream;
    _callSession.onRemoteStreamTrackReceived = _addRemoteMediaStream;
    _callSession.onSessionClosed = _onSessionClosed;
    _callSession.onPublishersReceived = onPublishersReceived;
    _callSession.onPublisherLeft = onPublisherLeft;
    _callSession.onError = onError;
    _callSession.onSubStreamChanged = onSubStreamChanged;
    _callSession.onLayerChanged = onLayerChanged;

    if (initialLocalMediaStream != null) {
      _callSession.localStream = initialLocalMediaStream;
      _addLocalMediaStream(initialLocalMediaStream!);
    }

    _callSession.joinDialog(_meetingId, ((publishers) {
      log("join session= $publishers", TAG);

      _callManager.requestParticipantsMediaConfig(publishers);

      _callSession.setMaxBandwidth(0);

      if (!_isIncoming) {
        _callManager.startNewOutgoingCall(_meetingId, _opponents,
            _callSession.currentUserId, _callSession.callType, _callName);
        _playDialing();
      } else {
        setState(() {
          _callStatus = 'Connected';
          _startCallTimer();
        });
      }
    }), conferenceRole: ConferenceRole.PUBLISHER);
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

    _playStoppingCall();
  }

  void _onCloseCall() {
    log("_onCloseCall", TAG);
    _callSession.leave();
  }

  void _onReceiveRejectCall(String meetingId, int participantId, bool isBusy) {
    log("_onReceiveRejectCall got reject from user $participantId", TAG);
  }

  void _onReceiveAcceptCall(int participantId) {
    log('[_onReceiveAcceptCall] from user $participantId', TAG);

    setState(() {
      _callStatus = 'Connected';
      _startCallTimer();
      _stopDialing();
    });
  }

  Future<void> _addLocalMediaStream(MediaStream stream) async {
    log("_addLocalMediaStream", TAG);

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
    log("[_closeSessionIfLast]", TAG);
    if (_callSession.allActivePublishers.length < 1) {
      log("[_closeSessionIfLast] 1", TAG);
      _callSession.leave();
    }
  }

  void _onSessionClosed(session) {
    log("[_onSessionClosed]", TAG);
    _statsReportsManager.dispose();
    _callManager.stopCall(_currentUser);
    _stopCallTimer();

    log("[_onSessionClosed] 2", TAG);
    Navigator.of(context, rootNavigator: true).pushReplacement(
      MaterialPageRoute(
        builder: (context) => SelectOpponentsScreen(_currentUser),
      ),
    );
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

  Future<void> _addMediaStream(
      int userId, bool isLocalStream, MediaStream stream,
      {String? trackId}) async {
    if (primaryRenderer == null) {
      primaryRenderer = MapEntry(userId, RTCVideoRenderer());
      await primaryRenderer!.value.initialize();

      setState(() {
        _setSourceForRenderer(primaryRenderer!.value, stream, isLocalStream,
            trackId: trackId);

        _chooseOpponentsStreamsQuality({
          userId: StreamType.high,
        });
      });

      return;
    }

    if (primaryRenderer?.key == userId) {
      _setSourceForRenderer(primaryRenderer!.value, stream, isLocalStream,
          trackId: trackId);

      _chooseOpponentsStreamsQuality({
        userId: StreamType.high,
      });

      return;
    }

    if (minorRenderers[userId] == null) {
      minorRenderers[userId] = RTCVideoRenderer();
      await minorRenderers[userId]?.initialize();
    }

    setState(() {
      _setSourceForRenderer(minorRenderers[userId]!, stream, isLocalStream,
          trackId: trackId);

      if (primaryRenderer?.key == currentUserId ||
          primaryRenderer?.key == userId ||
          ((primaryRenderer?.value.srcObject?.getVideoTracks().isEmpty ??
                  false) &&
              stream.getVideoTracks().isNotEmpty)) {
        _updatePrimaryUser(userId, true);
      }
    });
  }

  _setSourceForRenderer(
      RTCVideoRenderer renderer, MediaStream stream, bool isLocalStream,
      {String? trackId}) {
    isLocalStream || kIsWeb
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

    if (publishers.isNotEmpty) {
      _callManager.requestParticipantsMediaConfig(publishers);
    }
  }

  List<Widget> renderSpeakerModeViews(Orientation orientation) {
    log("[renderSpeakerModeViews]", TAG);
    List<Widget> streamsExpanded = [];

    addPrimaryVideoView() {
      if (canShowVideo(
          primaryRenderer?.key, primaryRenderer?.value.srcObject)) {
        streamsExpanded.add(
          Expanded(
            flex: 3,
            child: _buildPrimaryVideoView(orientation),
          ),
        );
      }
    }

    var minorUserWithEnabledVideo = getMinorUserWithEnabledVideo();

    if ((primaryRenderer?.key != currentUserId ||
            (primaryRenderer?.key == currentUserId &&
                (_primaryUserForciblySelected ||
                    minorUserWithEnabledVideo == null))) &&
        canShowVideo(primaryRenderer?.key, primaryRenderer?.value.srcObject)) {
      addPrimaryVideoView();
    } else if (minorUserWithEnabledVideo != null) {
      _updatePrimaryUser(minorUserWithEnabledVideo, true);
      _primaryUserForciblySelected = false;
      addPrimaryVideoView();
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

    if (minorItems.isNotEmpty) {
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
    log("[_updatePrimaryUser] userId: $userId, force: $force", TAG);
    if (layoutMode == LayoutMode.grid ||
        !minorRenderers.containsKey(userId) ||
        userId == primaryRenderer?.key ||
        (userId == currentUserId && !force) ||
        getMinorUserWithEnabledVideo() == null) return;

    _chooseOpponentsStreamsQuality({
      userId: StreamType.high,
      primaryRenderer!.key: StreamType.low,
    });

    if (primaryRenderer?.key != userId) {
      minorRenderers.addEntries([primaryRenderer!]);
    }

    primaryRenderer = MapEntry(userId, minorRenderers.remove(userId)!);
    _primaryUserForciblySelected = force;
  }

  void _onSpeakerChanged(int userId) {
    log("[_updatePrimaryUser] userId: $userId, currentUserId: $currentUserId",
        TAG);
    if (userId == currentUserId || layoutMode != LayoutMode.speaker) return;

    setState(() {
      if (canShowVideo(userId, minorRenderers[userId]?.srcObject)) {
        _updatePrimaryUser(userId, false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () => _onBackPressed(context),
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: Colors.green.shade100,
            body: _isVideoTracksPresent()
                ? OrientationBuilder(
                    builder: (context, orientation) {
                      return layoutMode == LayoutMode.private
                          ? _buildPrivateCallLayout(orientation)
                          : layoutMode == LayoutMode.speaker
                              ? _buildSpeakerModLayout(orientation)
                              : _buildGridModLayout(orientation);
                    },
                  )
                : _buildAudioCallLayout(),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: _getActionsPanel(),
          ),
          Visibility(
            visible:
                layoutMode != LayoutMode.private && _isVideoTracksPresent(),
            child: OrientationBuilder(
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

  Widget _buildPrivateCallLayout(Orientation orientation) {
    log("[_buildPrivateCallLayout]", TAG);
    List<Widget> videoItems = [];

    addPrimaryVideoView() {
      if (canShowVideo(
          primaryRenderer?.key, primaryRenderer?.value.srcObject)) {
        videoItems.add(_buildPrimaryVideoView(orientation));
      }
    }

    var minorUserWithEnabledVideo = getMinorUserWithEnabledVideo();

    if ((primaryRenderer?.key != currentUserId ||
            (primaryRenderer?.key == currentUserId &&
                (_primaryUserForciblySelected ||
                    minorUserWithEnabledVideo == null))) &&
        canShowVideo(primaryRenderer?.key, primaryRenderer?.value.srcObject)) {
      addPrimaryVideoView();
    } else if (minorUserWithEnabledVideo != null) {
      _updatePrimaryUser(minorUserWithEnabledVideo, true);
      _primaryUserForciblySelected = false;
      addPrimaryVideoView();
    }

    videoItems.add(
      Align(
        alignment: Alignment.topCenter,
        child: OrientationBuilder(
          builder: (context, orientation) {
            return Container(
                margin: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 48,
                ),
                child: _buildCallInfoLayout());
          },
        ),
      ),
    );

    var width = calculateMinorVideoViewWidth(orientation);
    var height = calculateMinorVideoViewHeight(orientation);

    var minorItem = buildItems(
      minorRenderers,
      width,
      height,
    ).firstOrNull;

    if (minorItem != null) {
      var widgetOffset = getOffsetForPosition(_minorWidgetPosition);

      if (_isWidgetMoving) {
        widgetOffset = _minorWidgetOffset;
      }

      videoItems.add(
        Positioned(
          top: widgetOffset.dy - height / 2,
          left: widgetOffset.dx - width / 2,
          child: minorItem,
        ),
      );
    }

    return Stack(children: videoItems);
  }

  Widget _buildSpeakerModLayout(Orientation orientation) {
    return Center(
        child: Container(
      child: Stack(children: [
        orientation == Orientation.portrait
            ? Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: renderSpeakerModeViews(orientation))
            : Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: renderSpeakerModeViews(orientation)),
        Align(
            alignment: Alignment.topCenter,
            child: Container(
                margin: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 48,
                ),
                child: _buildCallInfoLayout())),
      ]),
    ));
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
        padding: EdgeInsets.all(4),
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

  Widget _buildCallInfoLayout() {
    return Column(
      children: [
        Text(
          _getCallName(),
          style: TextStyle(
            fontSize: 24,
            color: Colors.white,
            decoration: TextDecoration.none,
            shadows: [
              Shadow(
                color: Colors.grey.shade900,
                offset: Offset(2, 1),
                blurRadius: 12,
              ),
            ],
          ),
        ),
        Text(
          _callStatus,
          style: TextStyle(
            fontSize: 14,
            color: Colors.white,
            decoration: TextDecoration.none,
            shadows: [
              Shadow(
                color: Colors.grey.shade900,
                offset: Offset(2, 1),
                blurRadius: 12,
              ),
            ],
          ),
        ),
        StreamBuilder<int>(
            stream: _callTimer.durationStream,
            builder: (context, snapshot) {
              return Text(
                snapshot.hasData ? formatHHMMSS(snapshot.data!) : '00:00',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white,
                  decoration: TextDecoration.none,
                  shadows: [
                    Shadow(
                      color: Colors.grey.shade900,
                      offset: Offset(2, 1),
                      blurRadius: 12,
                    ),
                  ],
                ),
              );
            })
      ],
    );
  }

  Widget _buildPrimaryVideoView(Orientation orientation) {
    return Stack(children: [
      GestureDetector(
        onDoubleTap: () => _switchPrimaryVideoFit(),
        child: RTCVideoView(
          primaryRenderer!.value,
          objectFit: primaryVideoFit,
          mirror: primaryRenderer!.key == currentUserId &&
              _isFrontCameraUsed &&
              _enableScreenSharing,
        ),
      ),
    ]);
  }

  List<Widget> buildItems(Map<int, RTCVideoRenderer> renderers,
      double itemWidth, double itemHeight) {
    var videoItems = <Widget>[];

    renderers.forEach((key, value) {
      if ((value.srcObject?.getVideoTracks().isNotEmpty ?? false) &&
          (participantsMediaConfigs[key]?[PARAM_IS_CAMERA_ENABLED] ?? true)) {
        videoItems.add(
          GestureDetector(
            onPanUpdate: (details) =>
                _onPanUpdate(context, details, _minorWidgetOffset),
            onPanEnd: (details) => _onPanEnd(context, details),
            onTap: () => setState(() {
              log("[onTap] userId: $key", TAG);
              _updatePrimaryUser(key, true);
            }),
            child: AbsorbPointer(
              child: SizedBox(
                width: itemWidth,
                height: itemHeight,
                child: Padding(
                  padding: EdgeInsets.all(6),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12.0),
                        child: RTCVideoView(
                          value,
                          objectFit:
                              RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                          mirror: key == currentUserId &&
                              _isFrontCameraUsed &&
                              _enableScreenSharing,
                        ),
                      ),
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          margin: EdgeInsets.only(bottom: 8),
                          child: Text(
                            key == currentUserId
                                ? 'Me'
                                : users
                                        .where((user) => user.id == key)
                                        .first
                                        .fullName ??
                                    'Unknown',
                            style: TextStyle(
                              color: Colors.white,
                              shadows: [
                                Shadow(
                                  color: Colors.black,
                                  offset: Offset(2, 1),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }
    });

    return videoItems;
  }

  void _onPanUpdate(
      BuildContext context, DragUpdateDetails details, Offset offset) {
    log('_onPanUpdate', TAG);
    if (layoutMode != LayoutMode.private) return;

    setState(() {
      _isWidgetMoving = true;
      _minorWidgetOffset = details.globalPosition;
    });
  }

  void _onPanEnd(BuildContext context, DragEndDetails details) {
    log('_onPanEnd', TAG);
    if (layoutMode != LayoutMode.private) return;

    setState(() {
      _isWidgetMoving = false;
      _minorWidgetPosition =
          calculateMinorVideoViewPosition(_minorWidgetOffset);
    });
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
                    visible: _isLocalVideoPresented(),
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
                    visible: _isLocalVideoPresented() && _enableScreenSharing,
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
    _callManager.stopCall(_currentUser);
    _callSession.leave();
    _stopCallTimer();
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
      _callManager.muteMic(_meetingId, _isMicMute);
      notifyParticipantsMediaUpdated();
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
    if (!_isVideoCall()) {
      showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              content: const Text(
                  'Are you sure you want to start the sharing of your video?'),
              actions: <Widget>[
                TextButton(
                  style: TextButton.styleFrom(
                    textStyle: Theme.of(context).textTheme.labelLarge,
                  ),
                  child: const Text('No'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    textStyle: Theme.of(context).textTheme.labelLarge,
                  ),
                  child: const Text('Yes'),
                  onPressed: () {
                    _addVideoTrack();
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          });
    } else {
      setState(() {
        _isCameraEnabled = !_isCameraEnabled;
        _callSession.setVideoEnabled(_isCameraEnabled);
        notifyParticipantsMediaUpdated();
      });
    }
  }

  _addVideoTrack() {
    navigator.mediaDevices
        .getUserMedia({'video': getVideoConfig()}).then((newMediaStream) {
      if (newMediaStream.getVideoTracks().isNotEmpty) {
        _callSession
            .addMediaTrack(newMediaStream.getVideoTracks().first)
            .whenComplete(() {
          log('The track added successfully', TAG);
          setState(() {
            _isCameraEnabled = true;
            _callSession.callType = CallType.VIDEO_CALL;
            notifyParticipantsMediaUpdated();
          });
        });
      }
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

  bool _isVideoTracksPresent() {
    var hasMinorVideo = false;
    minorRenderers.forEach((key, value) {
      if (value.srcObject?.getVideoTracks().isNotEmpty ?? false) {
        hasMinorVideo = true;
      }
    });

    return primaryRenderer != null &&
            (primaryRenderer?.value.srcObject?.getVideoTracks().isNotEmpty ??
                false) ||
        hasMinorVideo;
  }

  bool _isLocalVideoPresented() {
    if (primaryRenderer?.key == currentUserId) {
      return primaryRenderer?.value.srcObject?.getVideoTracks().isNotEmpty ??
          false;
    }

    var isLocalVideoPresented = false;

    minorRenderers.forEach((userId, renderer) {
      if (userId == currentUserId &&
          (renderer.srcObject?.getVideoTracks().isNotEmpty ?? false)) {
        isLocalVideoPresented = true;
      }
    });

    return isLocalVideoPresented;
  }

  Widget _buildAudioCallLayout() {
    return Align(
      alignment: Alignment.topCenter,
      child: Container(
          margin: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 48),
          child: _buildCallInfoLayout()),
    );
  }

  String _getCallName() {
    if (_isIncoming) return _callName;

    if (_opponents.length > 1) return 'Group call';

    var opponent = users.firstWhere(
        (savedUser) => savedUser.id == _opponents.first,
        orElse: () => CubeUser(fullName: 'Unknown user'));

    return opponent.fullName ?? 'Unknown user';
  }

  _startCallTimer() {
    _callTimer.start();
  }

  _stopCallTimer() {
    _callTimer.stop();
  }

  void _onCallMuted(String meetingId, bool isMuted) {
    if (meetingId == _meetingId) {
      setState(() {
        _isMicMute = isMuted;
        _callSession.setMicrophoneMute(isMuted);
      });
    }
  }

  bool canShowVideo(int? userId, MediaStream? mediaStream) {
    if (userId == null || mediaStream == null) return false;

    if (mediaStream.getVideoTracks().isEmpty) return false;

    var hasEnabledVideo = false;

    mediaStream.getVideoTracks().forEach((videoTrack) {
      if (!hasEnabledVideo && videoTrack.enabled) {
        hasEnabledVideo = true;
      }
    });

    return hasEnabledVideo &&
        (participantsMediaConfigs[userId]?[PARAM_IS_CAMERA_ENABLED] ?? false);
  }

  int? getMinorUserWithEnabledVideo() {
    var resultUserId = -1;

    minorRenderers.forEach((userId, renderer) {
      if ((resultUserId == -1 || resultUserId == currentUserId) &&
          canShowVideo(userId, renderer.srcObject)) {
        resultUserId = userId;
      }
    });

    return resultUserId == -1 ? null : resultUserId;
  }

  Map<String, bool> _getMediaState() {
    return {
      PARAM_IS_MIC_ENABLED: !_isMicMute,
      PARAM_IS_CAMERA_ENABLED: _isCameraEnabled
    };
  }

  void _onParticipantMediaUpdated(int userId, Map<String, bool> mediaConfig) {
    setState(() {
      participantsMediaConfigs[userId] = mediaConfig;
    });
  }

  void notifyParticipantsMediaUpdated() {
    participantsMediaConfigs[currentUserId] = {
      PARAM_IS_MIC_ENABLED: !_isMicMute,
      PARAM_IS_CAMERA_ENABLED: _isCameraEnabled
    };

    _callManager.notifyParticipantsMediaUpdated({
      PARAM_IS_MIC_ENABLED: !_isMicMute,
      PARAM_IS_CAMERA_ENABLED: _isCameraEnabled
    });
  }

  WidgetPosition calculateMinorVideoViewPosition(Offset initialPosition) {
    var isRight = false;
    if (initialPosition.dx > MediaQuery.of(context).size.width / 2) {
      isRight = true;
    }

    var isBottom = false;
    if (initialPosition.dy > MediaQuery.of(context).size.height / 2) {
      isBottom = true;
    }

    var position = WidgetPosition.topRight;

    if (isRight && isBottom) {
      position = WidgetPosition.bottomRight;
    } else if (!isRight && isBottom) {
      position = WidgetPosition.bottomLeft;
    } else if (!isRight && !isBottom) {
      position = WidgetPosition.topLeft;
    }

    return position;
  }

  double calculateMinorVideoViewWidth(Orientation orientation) {
    return orientation == Orientation.portrait
        ? MediaQuery.of(context).size.width / 3
        : MediaQuery.of(context).size.width / 4;
  }

  double calculateMinorVideoViewHeight(Orientation orientation) {
    return orientation == Orientation.portrait
        ? MediaQuery.of(context).size.height / 4
        : MediaQuery.of(context).size.height / 2.5;
  }

  Offset getOffsetForPosition(WidgetPosition position) {
    var orientation = MediaQuery.of(context).orientation;

    var width = calculateMinorVideoViewWidth(orientation);
    var height = calculateMinorVideoViewHeight(orientation);

    var dxPosition = 0.0;
    if (position == WidgetPosition.topRight ||
        position == WidgetPosition.bottomRight) {
      dxPosition = MediaQuery.of(context).size.width -
          (width / 2 + MediaQuery.of(context).padding.right + 10);
    } else {
      dxPosition = width / 2 + MediaQuery.of(context).padding.left + 10;
    }

    var dyPosition = 0.0;
    if (position == WidgetPosition.bottomRight ||
        position == WidgetPosition.bottomLeft) {
      dyPosition = MediaQuery.of(context).size.height -
          (height / 2 + MediaQuery.of(context).padding.bottom + 10);
    } else {
      dyPosition = height / 2 + MediaQuery.of(context).padding.top + 10;
    }

    return Offset(dxPosition, dyPosition);
  }

  void _playDialing() {
    _ringtonePlayer.open(
        Audio("assets/audio/dialing.mp3"),
        loopMode: LoopMode.single
    );
  }

  void _stopDialing() {
    _ringtonePlayer.stop();
  }

  void _playStoppingCall() {
    _ringtonePlayer.open(
        Audio("assets/audio/end_call.mp3"),
        loopMode: LoopMode.none
    );
  }
}

enum LayoutMode { speaker, grid, private }

enum WidgetPosition { topLeft, topRight, bottomLeft, bottomRight }
