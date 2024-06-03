import 'dart:async';
import 'dart:io';

import 'package:assets_audio_player/assets_audio_player.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:connectycube_sdk/connectycube_sdk.dart';

import '../managers/call_manager.dart';
import '../utils/configs.dart';
import '../utils/consts.dart';
import '../utils/duration_timer.dart';
import '../utils/media_utils.dart';
import '../utils/platform_utils.dart';
import '../utils/users_utils.dart';
import '../widgets/call_controls_widget.dart';
import '../widgets/call_info_widget.dart';
import '../widgets/grid_view_call_widget.dart';
import '../widgets/private_call_widget.dart';
import '../widgets/speaker_view_call_widget.dart';

class ConversationCallScreen extends StatefulWidget {
  final CubeUser currentUser;
  final ConferenceSession callSession;
  final String meetingId;
  final List<int> opponents;
  final bool isIncoming;
  final String callName;
  final MediaStream? initialLocalMediaStream;
  final bool? isFrontCameraUsed;
  final bool? isSharedCall;

  @override
  State<StatefulWidget> createState() {
    return _ConversationCallScreenState();
  }

  const ConversationCallScreen(this.currentUser, this.callSession,
      this.meetingId, this.opponents, this.isIncoming, this.callName,
      {super.key,
      this.initialLocalMediaStream,
      this.isFrontCameraUsed = true,
      this.isSharedCall = false});
}

class _ConversationCallScreenState extends State<ConversationCallScreen> {
  static const String tag = "_ConversationCallScreenState";
  static const LayoutMode defaultLayoutMode = LayoutMode.speaker;

  final CallManager _callManager = CallManager.instance;
  final CubeStatsReportsManager _statsReportsManager =
      CubeStatsReportsManager();

  LayoutMode layoutMode = defaultLayoutMode;
  String _callStatus = 'Waiting...';
  bool _isCameraEnabled = true;
  bool _isSpeakerEnabled = true;
  bool _isMicMute = false;
  bool _enableScreenSharing = false;
  bool _isFrontCameraUsed = true;
  bool _isSharedCall = false;
  RTCVideoViewObjectFit primaryVideoFit =
      RTCVideoViewObjectFit.RTCVideoViewObjectFitCover;
  int currentUserId = -1;
  final DurationTimer _callTimer = DurationTimer();
  MapEntry<int, RTCVideoRenderer>? primaryRenderer;
  Map<int, RTCVideoRenderer> minorRenderers = {};
  Map<int, Map<String, bool>> participantsMediaConfigs = {};
  WidgetPosition _minorWidgetPosition = WidgetPosition.topRight;
  final AssetsAudioPlayer _ringtonePlayer = AssetsAudioPlayer.newPlayer();

  @override
  void initState() {
    super.initState();
    _enableScreenSharing = !widget.callSession.startScreenSharing;
    _isCameraEnabled = widget.callSession.callType == CallType.VIDEO_CALL;
    currentUserId = widget.currentUser.id!;
    _isFrontCameraUsed = widget.isFrontCameraUsed ?? true;
    _isSharedCall = widget.isSharedCall ?? false;

    if (widget.opponents.length == 1) {
      layoutMode = LayoutMode.private;
    }

    if (widget.initialLocalMediaStream != null) {
      _isMicMute = !(widget.initialLocalMediaStream
          ?.getAudioTracks()
          .firstOrNull
          ?.enabled ??
          false);
      _isCameraEnabled = widget.initialLocalMediaStream
          ?.getVideoTracks()
          .firstOrNull
          ?.enabled ??
          false;
    }

    participantsMediaConfigs[currentUserId] = {
      paramIsMicEnabled: !_isMicMute,
      paramIsCameraEnabled: _isCameraEnabled
    };

    _statsReportsManager.init(widget.callSession);

    _callManager.onReceiveRejectCall = _onReceiveRejectCall;
    _callManager.onReceiveAcceptCall = _onReceiveAcceptCall;
    _callManager.onCloseCall = _onCloseCall;
    _callManager.onCallMuted = _onCallMuted;
    _callManager.getMediaState = _getMediaState;
    _callManager.onParticipantMediaUpdated = _onParticipantMediaUpdated;

    widget.callSession.onLocalStreamReceived = _addLocalMediaStream;
    widget.callSession.onRemoteStreamTrackReceived = _addRemoteMediaStream;
    widget.callSession.onSessionClosed = _onSessionClosed;
    widget.callSession.onPublishersReceived = onPublishersReceived;
    widget.callSession.onPublisherLeft = onPublisherLeft;
    widget.callSession.onError = onError;
    widget.callSession.onSubStreamChanged = onSubStreamChanged;
    widget.callSession.onLayerChanged = onLayerChanged;

    if (widget.initialLocalMediaStream != null) {
      widget.callSession.localStream = widget.initialLocalMediaStream;
      _addLocalMediaStream(widget.initialLocalMediaStream!);
    }

    widget.callSession.joinDialog(widget.meetingId, ((publishers) {
      log("join session= $publishers", tag);

      _callManager.requestParticipantsMediaConfig(publishers);

      widget.callSession.setMaxBandwidth(0);

      if (!widget.isIncoming) {
        _callManager.startNewOutgoingCall(
            widget.meetingId,
            widget.opponents,
            widget.callSession.currentUserId,
            widget.callSession.callType,
            widget.callName,
            widget.currentUser.avatar);
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
    _statsReportsManager.dispose();

    stopBackgroundExecution();

    primaryRenderer?.value.srcObject = null;
    primaryRenderer?.value.dispose();

    minorRenderers.forEach((opponentId, renderer) {
      log("[dispose] dispose renderer for $opponentId", tag);
      try {
        renderer.srcObject = null;
        renderer.dispose();
      } catch (e) {
        log('Error $e');
      }
    });

    _playStoppingCall();

    super.dispose();
  }

  void _onCloseCall() {
    log("_onCloseCall", tag);
    widget.callSession.leave();
  }

  void _onReceiveRejectCall(String meetingId, int participantId, bool isBusy) {
    log("_onReceiveRejectCall got reject from user $participantId", tag);
  }

  void _onReceiveAcceptCall(int participantId) {
    log('[_onReceiveAcceptCall] from user $participantId', tag);

    setState(() {
      _callStatus = 'Connected';
      _startCallTimer();
      _stopDialing();
    });
  }

  Future<void> _addLocalMediaStream(MediaStream stream) async {
    log("_addLocalMediaStream", tag);

    _addMediaStream(currentUserId, true, stream);
  }

  void _addRemoteMediaStream(session, int userId, MediaStream stream,
      {String? trackId}) {
    log("_addRemoteMediaStream for user $userId", tag);

    _addMediaStream(userId, false, stream, trackId: trackId);
  }

  void _removeMediaStream(callSession, int userId) {
    log("_removeMediaStream for user $userId", tag);
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
          chooseOpponentsStreamsQuality(widget.callSession, currentUserId,
              {userIdToRemoveRenderer: StreamType.high});
        });
      }
    }
  }

  void _closeSessionIfLast() {
    log("[_closeSessionIfLast]", tag);
    if (widget.callSession.allActivePublishers.isEmpty) {
      log("[_closeSessionIfLast] 1", tag);
      widget.callSession.leave();
    }
  }

  void _onSessionClosed(session) {
    log("[_onSessionClosed]", tag);
    _statsReportsManager.dispose();
    _callManager.stopCall(widget.currentUser);
    _stopCallTimer();

    Navigator.of(context).pushNamedAndRemoveUntil(
        selectOpponentsScreen, ModalRoute.withName(selectOpponentsScreen),
        arguments: {argUser: widget.currentUser});
  }

  void onPublishersReceived(publishers) {
    log("onPublishersReceived", tag);
    handlePublisherReceived(publishers);
  }

  void onPublisherLeft(publisher) {
    log("onPublisherLeft $publisher", tag);
    _removeMediaStream(widget.callSession, publisher);
    _callManager.processParticipantLeave(publisher);
    _closeSessionIfLast();
  }

  void onError(ex) {
    log("onError $ex", tag);
  }

  void onSubStreamChanged(int userId, StreamType streamType) {
    log("onSubStreamChanged userId: $userId, streamType: $streamType", tag);
  }

  void onLayerChanged(int userId, int layer) {
    log("onLayerChanged userId: $userId, layer: $layer", tag);
  }

  Future<void> _addMediaStream(
      int userId, bool isLocalStream, MediaStream stream,
      {String? trackId}) async {
    log('[_addMediaStream] userId: $userId, isLocalStream: $isLocalStream',
        tag);

    if (primaryRenderer == null) {
      primaryRenderer = MapEntry(userId, RTCVideoRenderer());
      await primaryRenderer!.value.initialize();

      setState(() {
        _setSourceForRenderer(primaryRenderer!.value, stream, isLocalStream,
            trackId: trackId);

        chooseOpponentsStreamsQuality(widget.callSession, currentUserId, {
          userId: StreamType.high,
        });
      });

      return;
    }

    if (primaryRenderer?.key == userId) {
      _setSourceForRenderer(primaryRenderer!.value, stream, isLocalStream,
          trackId: trackId);

      chooseOpponentsStreamsQuality(widget.callSession, currentUserId, {
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
    if (!widget.isIncoming) {
      for (var id in publishers) {
        if (id != null) {
          _callManager.handleAcceptCall(id);
        }
      }
    }

    if (publishers.isNotEmpty) {
      _callManager.requestParticipantsMediaConfig(publishers);
    }
  }

  void _updatePrimaryUser(int userId, bool force) {
    log("[_updatePrimaryUser] userId: $userId, force: $force", tag);

    if (layoutMode == LayoutMode.grid) return;

    log("[_updatePrimaryUser] 2", tag);
    updatePrimaryUser(
      userId,
      force,
      currentUserId,
      primaryRenderer,
      minorRenderers,
      participantsMediaConfigs,
      onRenderersUpdated: _updateRenderers,
    );
    log("[_updatePrimaryUser] 3", tag);
  }

  _updateRenderers(MapEntry<int, RTCVideoRenderer>? updatedPrimaryRenderer,
      Map<int, RTCVideoRenderer> updatedMinorRenderers) {
    if (updatedPrimaryRenderer?.key != primaryRenderer?.key) {
      chooseOpponentsStreamsQuality(widget.callSession, currentUserId, {
        if (updatedPrimaryRenderer?.key != null)
          updatedPrimaryRenderer!.key: StreamType.high,
        if (primaryRenderer?.key != null) primaryRenderer!.key: StreamType.low,
      });
    }

    primaryRenderer = updatedPrimaryRenderer;
    minorRenderers = updatedMinorRenderers;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
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
                        ? const EdgeInsets.only(top: 40, left: 16)
                        : const EdgeInsets.only(left: 16, top: 20),
                    child: FloatingActionButton(
                      elevation: 0,
                      heroTag: "ToggleScreenMode",
                      onPressed: () => _switchLayoutMode(),
                      backgroundColor: Colors.black38,
                      child: Icon(
                        layoutMode == LayoutMode.speaker
                            ? Icons.grid_view_rounded
                            : Icons.view_sidebar_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Visibility(
            visible: layoutMode != LayoutMode.private,
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Container(
                margin: const EdgeInsets.only(bottom: 96, left: 16),
                child: FloatingActionButton(
                  elevation: 0,
                  heroTag: "CopyConferenceUrl",
                  onPressed: () {
                    _copyConferenceUrlToClipboard();
                  },
                  backgroundColor: Colors.green,
                  child: const Icon(
                    Icons.share,
                    color: Colors.white,
                  ),
                ),
              ),
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

      Map<int, StreamType> config;
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

      chooseOpponentsStreamsQuality(widget.callSession, currentUserId, config);
    });
  }

  Widget _buildPrivateCallLayout(Orientation orientation) {
    return PrivateCallLayout(
      currentUserId: currentUserId,
      primaryRenderer: primaryRenderer,
      primaryVideoFit: primaryVideoFit,
      minorRenderers: minorRenderers,
      callName: _getCallName(),
      callStatus: _callStatus,
      callTimer: _callTimer,
      minorWidgetInitialPosition: _minorWidgetPosition,
      isFrontCameraUsed: _isFrontCameraUsed,
      isScreenSharingEnabled: !_enableScreenSharing,
      participantsMediaConfigs: participantsMediaConfigs,
      onMinorVideoPositionChanged: (newPosition) {
        _minorWidgetPosition = newPosition;
      },
      onPrimaryVideoFitChanged: (newObjectFit) {
        setState(() {
          primaryVideoFit = newObjectFit;
        });
      },
      onRenderersChanged: _updateRenderers,
    );
  }

  Widget _buildSpeakerModLayout(Orientation orientation) {
    return SpeakerViewLayout(
      currentUserId: currentUserId,
      participants: users,
      primaryRenderer: primaryRenderer,
      primaryVideoFit: primaryVideoFit,
      minorRenderers: minorRenderers,
      callName: _getCallName(),
      callStatus: _callStatus,
      callTimer: _callTimer,
      isFrontCameraUsed: _isFrontCameraUsed,
      isScreenSharingEnabled: !_enableScreenSharing,
      participantsMediaConfigs: participantsMediaConfigs,
      onPrimaryVideoFitChanged: (newObjectFit) {
        setState(() {
          primaryVideoFit = newObjectFit;
        });
      },
      onRenderersChanged: _updateRenderers,
      statsReportsManager: _statsReportsManager,
      getUserName: (userId) => _getUserName(userId),
    );
  }

  Widget _buildGridModLayout(Orientation orientation) {
    return GridViewLayout(
      currentUserId: currentUserId,
      participants: users,
      primaryRenderer: primaryRenderer,
      minorRenderers: minorRenderers,
      isFrontCameraUsed: _isFrontCameraUsed,
      isScreenSharingEnabled: !_enableScreenSharing,
      participantsMediaConfigs: participantsMediaConfigs,
      onRenderersChanged: _updateRenderers,
      statsReportsManager: _statsReportsManager,
      getUserName: (userId) => _getUserName(userId),
    );
  }

  Widget _getActionsPanel() {
    return CallControls(
      isMicMuted: _isMicMute,
      onMute: _muteMic,
      isCameraButtonVisible: _enableScreenSharing,
      isCameraEnabled: _isVideoEnabled(),
      onToggleCamera: _toggleCamera,
      isScreenSharingButtonVisible: _isLocalVideoPresented(),
      isScreenSharingEnabled: !_enableScreenSharing,
      onToggleScreenSharing: _toggleScreenSharing,
      isSpeakerEnabled: _isSpeakerEnabled,
      onSwitchSpeaker: _switchSpeaker,
      onSwitchAudioInput: _switchAudioInput,
      isSwitchCameraButtonVisible:
          _isLocalVideoPresented() && _enableScreenSharing,
      onSwitchCamera: _switchCamera,
      onEndCall: _endCall,
    );
  }

  _endCall() {
    _callManager.stopCall(widget.currentUser);
    widget.callSession.leave();
    _stopCallTimer();
  }

  _muteMic() {
    setState(() {
      _isMicMute = !_isMicMute;
      widget.callSession.setMicrophoneMute(_isMicMute);
      _callManager.muteMic(widget.meetingId, _isMicMute);
      notifyParticipantsMediaUpdated();
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
        widget.callSession.setVideoEnabled(_isCameraEnabled);
        notifyParticipantsMediaUpdated();
      });
    }
  }

  _addVideoTrack() {
    navigator.mediaDevices
        .getUserMedia({'video': getVideoConfig()}).then((newMediaStream) {
      if (newMediaStream.getVideoTracks().isNotEmpty) {
        widget.callSession
            .addMediaTrack(newMediaStream.getVideoTracks().first)
            .whenComplete(() {
          log('The track added successfully', tag);
          setState(() {
            _isCameraEnabled = true;
            widget.callSession.callType = CallType.VIDEO_CALL;
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

    var desktopCapturerSource = _enableScreenSharing && isDesktop && mounted
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

  bool _isVideoTracksPresent() {
    var hasMinorVideo = false;
    minorRenderers.forEach((key, value) {
      if (canShowVideo(key, value.srcObject, participantsMediaConfigs)) {
        hasMinorVideo = true;
      }
    });

    return (primaryRenderer != null &&
            canShowVideo(primaryRenderer?.key, primaryRenderer?.value.srcObject,
                participantsMediaConfigs)) ||
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
          child: CallInfo(_getCallName(), _callStatus, _callTimer)),
    );
  }

  String _getCallName() {
    if (_isSharedCall) return 'Shared conference';

    if (widget.isIncoming) return widget.callName;

    if (widget.opponents.length > 1) return 'Group call';

    var opponent = users.firstWhere(
        (savedUser) => savedUser.id == widget.opponents.firstOrNull,
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
    if (meetingId == widget.meetingId) {
      setState(() {
        _isMicMute = isMuted;
        widget.callSession.setMicrophoneMute(isMuted);
      });
    }
  }

  Map<String, bool> _getMediaState() {
    return {
      paramIsMicEnabled: !_isMicMute,
      paramIsCameraEnabled: _isCameraEnabled
    };
  }

  void _onParticipantMediaUpdated(int userId, Map<String, bool> mediaConfig) {
    setState(() {
      participantsMediaConfigs[userId] = mediaConfig;
    });
  }

  void notifyParticipantsMediaUpdated() {
    participantsMediaConfigs[currentUserId] = {
      paramIsMicEnabled: !_isMicMute,
      paramIsCameraEnabled: _isCameraEnabled
    };

    _callManager.notifyParticipantsMediaUpdated({
      paramIsMicEnabled: !_isMicMute,
      paramIsCameraEnabled: _isCameraEnabled
    });
  }

  void _playDialing() {
    _ringtonePlayer.open(Audio("assets/audio/dialing.mp3"),
        loopMode: LoopMode.single);
  }

  void _stopDialing() {
    _ringtonePlayer.stop();
  }

  void _playStoppingCall() {
    _ringtonePlayer.open(Audio("assets/audio/end_call.mp3"),
        loopMode: LoopMode.none);
  }

  Future<String> _getUserName(int userId) {
    if (userId == widget.currentUser.id) return Future.value('Me');

    return getUserNameCached(userId);
  }

  void _copyConferenceUrlToClipboard() {
    Clipboard.setData(ClipboardData(
            text: '${getAppHost()}?$argMeetingId=${widget.meetingId}'))
        .then((_) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('URL copied'),
            content: const Text(
                'The conference URL was copied to the clipboard. Any user can join the current call by this link.'),
            actions: <Widget>[
              TextButton(
                child: const Text("OK"),
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
            ],
          );
        },
      );
    });
  }
}

enum LayoutMode { speaker, grid, private }
