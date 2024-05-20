import 'package:assets_audio_player/assets_audio_player.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:universal_io/io.dart';

import 'package:connectycube_sdk/connectycube_sdk.dart';

import '../managers/call_manager.dart';

class IncomingCallScreen extends StatefulWidget {
  static const String tag = "IncomingCallScreen";
  final CubeUser currentUser;
  final String callId;
  final String meetingId;
  final int initiatorId;
  final List<int> participantIds;
  final int callType;
  final String callName;

  const IncomingCallScreen(this.currentUser, this.callId, this.meetingId,
      this.initiatorId, this.participantIds, this.callType, this.callName,
      {super.key});

  @override
  State<StatefulWidget> createState() {
    return _IncomingCallScreenState();
  }
}

class _IncomingCallScreenState extends State<IncomingCallScreen> {
  static const String tag = "_IncomingCallScreenState";
  final CallManager _callManager = CallManager.instance;
  bool _isFrontCameraSelected = true;
  bool _isMicMute = false;
  MediaStream? _localMediaStream;
  RTCVideoRenderer? _localVideoRenderer;
  final AssetsAudioPlayer _ringtonePlayer = AssetsAudioPlayer.newPlayer();

  @override
  void initState() {
    super.initState();
    log('[initState]', tag);

    _callManager.onCloseCall = _onCallClosed;
    _callManager.onCallAccepted = _onCallAccepted;
    _callManager.onCallRejected = _onCallRejected;
  }

  @override
  Widget build(BuildContext context) {
    log('[build]', tag);
    if (_callManager.currentCallState != InternalCallState.initial) {
      closeScreen();
      return const SizedBox.shrink();
    }

    _playRingtone();

    return PopScope(
      canPop: false,
      child: Scaffold(
          backgroundColor: Colors.green.shade100,
          body: FutureBuilder<MediaStream?>(
            future: _getLocalMediaStream(),
            builder: (context, snapshot) {
              return Stack(
                children: [
                  if (snapshot.hasData)
                    FutureBuilder(
                      future: getVideoRenderer(snapshot.data),
                      builder: (BuildContext context,
                          AsyncSnapshot<dynamic> snapshot2) {
                        if (!snapshot2.hasData) {
                          return const SizedBox.shrink();
                        }

                        return RTCVideoView(
                          snapshot2.data,
                          objectFit:
                              RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                          mirror: _isFrontCameraSelected,
                        );
                      },
                    ),
                  Container(
                    margin: EdgeInsets.only(
                        top: MediaQuery.of(context).padding.top + 80),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text(widget.callName,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  shadows: [
                                    Shadow(
                                      color: Colors.grey.shade900,
                                      offset: const Offset(2, 1),
                                      blurRadius: 12,
                                    ),
                                  ],
                                )),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text(_getCallTitle(),
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.white,
                                  shadows: [
                                    Shadow(
                                      color: Colors.grey.shade900,
                                      offset: const Offset(2, 1),
                                      blurRadius: 12,
                                    ),
                                  ],
                                )),
                          ),
                          const Expanded(
                            flex: 1,
                            child: SizedBox(),
                          ),
                          Visibility(
                            visible: widget.callType == CallType.VIDEO_CALL,
                            child: Padding(
                              padding: EdgeInsets.only(
                                  bottom:
                                      MediaQuery.of(context).padding.bottom +
                                          120),
                              child: Row(
                                // crossAxisAlignment: CrossAxisAlignment.center,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16),
                                    child: FloatingActionButton(
                                      elevation: 0,
                                      heroTag: "ToggleCamera",
                                      onPressed: () => _toggleCamera(),
                                      backgroundColor: isVideoEnabledInStream(
                                              _localMediaStream)
                                          ? Colors.white
                                          : Colors.grey,
                                      child: Icon(
                                        isVideoEnabledInStream(
                                                _localMediaStream)
                                            ? Icons.videocam
                                            : Icons.videocam_off,
                                        color: isVideoEnabledInStream(
                                                _localMediaStream)
                                            ? Colors.grey
                                            : Colors.white,
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16),
                                    child: FloatingActionButton(
                                      elevation: 0,
                                      heroTag: "Mute",
                                      onPressed: () => _muteMic(),
                                      backgroundColor: _isMicMute
                                          ? Colors.grey
                                          : Colors.white,
                                      child: Icon(
                                        _isMicMute ? Icons.mic_off : Icons.mic,
                                        color: _isMicMute
                                            ? Colors.white
                                            : Colors.grey,
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16),
                                    child: FloatingActionButton(
                                      elevation: 0,
                                      heroTag: "SwitchCamera",
                                      onPressed: () => _switchCamera(),
                                      backgroundColor: Colors.black38,
                                      child: Icon(
                                        Icons.cameraswitch,
                                        color: isVideoEnabledInStream(
                                                _localMediaStream)
                                            ? Colors.white
                                            : Colors.grey,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.only(
                                bottom:
                                    MediaQuery.of(context).padding.bottom + 80),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Padding(
                                  padding: const EdgeInsets.only(right: 36),
                                  child: FloatingActionButton(
                                    heroTag: "RejectCall",
                                    backgroundColor: Colors.red,
                                    onPressed: () => _rejectCall(),
                                    child: const Icon(
                                      Icons.call_end,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(left: 36),
                                  child: FloatingActionButton(
                                    heroTag: "AcceptCall",
                                    backgroundColor: Colors.green,
                                    onPressed: () =>
                                        _acceptCall(widget.callType),
                                    child: Icon(
                                      widget.callType == CallType.VIDEO_CALL
                                          ? Icons.videocam
                                          : Icons.call,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          )),
    );
  }

  _getCallTitle() {
    log('[_getCallTitle]', tag);
    String callType =
        widget.callType == CallType.VIDEO_CALL ? "Video" : 'Audio';
    return "Incoming $callType call";
  }

  void _acceptCall(int callType) async {
    log('[_acceptCall]', tag);
    _callManager.startNewIncomingCall(
        context,
        widget.currentUser,
        widget.callId,
        widget.meetingId,
        callType,
        widget.callName,
        widget.initiatorId,
        widget.participantIds,
        false,
        initialLocalMediaStream: _localMediaStream,
        isFrontCameraUsed: _isFrontCameraSelected);
  }

  void _rejectCall() {
    log('[_rejectCall]', tag);
    _localMediaStream?.getTracks().forEach((track) async {
      await track.stop();
    });
    _localMediaStream?.dispose();

    _callManager.reject(
        widget.callId, widget.meetingId, false, widget.initiatorId, false);
    closeScreen();
  }

  @override
  void dispose() {
    log('[dispose]', tag);
    _localVideoRenderer?.srcObject = null;
    _localVideoRenderer?.dispose();

    _callManager.onCloseCall = null;
    _callManager.onCallAccepted = null;
    _callManager.onCallRejected = null;

    _stopRingtone();

    super.dispose();
  }

  void _onCallClosed() {
    log('[_onCallClosed]', tag);
    _localMediaStream?.getTracks().forEach((track) async {
      await track.stop();
    });
    _localMediaStream?.dispose();

    closeScreen();
  }

  void _onCallAccepted(String meetingId) {
    log('[_onCallAccepted]', tag);
  }

  void _onCallRejected(String meetingId) {
    log('[_onCallRejected]', tag);
    if (meetingId == widget.meetingId) {
      _localMediaStream?.getTracks().forEach((track) async {
        await track.stop();
      });
      _localMediaStream?.dispose();

      closeScreen();
    }
  }

  Future<MediaStream?> _getLocalMediaStream() {
    log('[_getLocalMediaStream]', tag);
    if (widget.callType == CallType.AUDIO_CALL) return Future.value(null);
    if (_localMediaStream != null) return Future.value(_localMediaStream);

    return navigator.mediaDevices
        .getUserMedia(getMediaConstraints())
        .then((localMediaStream) {
      _localMediaStream = localMediaStream;

      return localMediaStream;
    });
  }

  Map<String, dynamic> getMediaConstraints() {
    log('[getMediaConstraints]', tag);
    final Map<String, dynamic> mediaConstraints = {
      'audio': getAudioConfig(),
    };

    if (CallType.VIDEO_CALL == widget.callType) {
      mediaConstraints['video'] = getVideoConfig();
    }

    return mediaConstraints;
  }

  Future<RTCVideoRenderer> getVideoRenderer(MediaStream? mediaStream) {
    log('[getVideoRenderer]', tag);
    if (_localVideoRenderer != null) return Future.value(_localVideoRenderer);

    var videoRenderer = RTCVideoRenderer();

    return videoRenderer.initialize().then((value) {
      videoRenderer.srcObject = mediaStream;
      _localVideoRenderer = videoRenderer;
      return videoRenderer;
    });
  }

  _muteMic() {
    if (_localMediaStream == null) return;

    setState(() {
      _isMicMute = !_isMicMute;

      var audioTrack = _localMediaStream?.getAudioTracks().firstOrNull;

      if (audioTrack != null) {
        Helper.setMicrophoneMute(_isMicMute, audioTrack);
      }
    });
  }

  _toggleCamera() {
    if (_localMediaStream == null) return;

    setState(() {
      _localMediaStream?.getVideoTracks().firstOrNull?.enabled =
          !isVideoEnabledInStream(_localMediaStream);
    });
  }

  _switchCamera() {
    if (_localMediaStream == null) return;

    if (!isVideoEnabledInStream(_localMediaStream)) return;

    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      switchCamera().then((isFrontCameraUsed) {
        setState(() {
          _isFrontCameraSelected = isFrontCameraUsed;
        });
      });
    } else {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return FutureBuilder<List<MediaDeviceInfo>>(
            future: Helper.cameras,
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
        if (deviceId != null) switchCamera(deviceId: deviceId);
      });
    }
  }

  bool isVideoEnabledInStream(MediaStream? mediaStream) {
    if (mediaStream == null) return false;

    if (mediaStream.getVideoTracks().isEmpty) return false;

    return mediaStream.getVideoTracks().first.enabled;
  }

  Future<bool> switchCamera({String? deviceId}) async {
    try {
      if (_localMediaStream == null) {
        return Future.error(IllegalStateException(
            "Can't perform operation [switchCamera], cause 'localStream' not initialised"));
      } else {
        if (deviceId != null) {
          var newMediaStream = await navigator.mediaDevices.getUserMedia({
            'audio': false,
            'video': kIsWeb
                ? {'deviceId': deviceId}
                : getVideoConfig(deviceId: deviceId),
          });

          var oldVideoTrack = _localMediaStream!.getVideoTracks()[0];

          await _localMediaStream?.removeTrack(oldVideoTrack);
          oldVideoTrack.stop();

          await _localMediaStream?.addTrack(newMediaStream.getVideoTracks()[0]);

          return Future.value(true);
        } else {
          final videoTrack = _localMediaStream!.getVideoTracks()[0];
          return Helper.switchCamera(videoTrack, null, _localMediaStream);
        }
      }
    } catch (error) {
      return Future.error(error);
    }
  }

  closeScreen() {
    Navigator.of(context).pop();
  }

  void _playRingtone() {
    _ringtonePlayer.open(Audio("assets/audio/calling.mp3"),
        loopMode: LoopMode.single);
  }

  void _stopRingtone() {
    _ringtonePlayer.stop();
  }
}
