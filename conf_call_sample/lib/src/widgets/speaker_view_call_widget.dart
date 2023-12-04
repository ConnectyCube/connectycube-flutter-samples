import 'package:flutter/material.dart';

import 'package:connectycube_sdk/connectycube_sdk.dart';

import '../utils/duration_timer.dart';
import '../utils/media_utils.dart';
import '../managers/speakers_manager.dart';
import 'call_info_widget.dart';
import 'minor_video_widget.dart';
import 'primary_video_widget.dart';

class SpeakerViewLayout extends StatefulWidget {
  final MapEntry<int, RTCVideoRenderer>? primaryRenderer;
  final Map<int, RTCVideoRenderer> minorRenderers;
  final RTCVideoViewObjectFit primaryVideoFit;
  final Function(RTCVideoViewObjectFit newObjectFit)? onPrimaryVideoFitChanged;
  final int currentUserId;
  final List<CubeUser> participants;
  final String callName;
  final String callStatus;
  final DurationTimer callTimer;
  final bool isFrontCameraUsed;
  final bool isScreenSharingEnabled;
  final Map<int, Map<String, bool>> participantsMediaConfigs;
  final Function(MapEntry<int, RTCVideoRenderer>? primaryRenderer,
      Map<int, RTCVideoRenderer> minorRenderers) onRenderersChanged;
  final CubeStatsReportsManager statsReportsManager;

  SpeakerViewLayout({
    super.key,
    required this.currentUserId,
    required this.participants,
    required this.primaryRenderer,
    required this.primaryVideoFit,
    this.onPrimaryVideoFitChanged,
    required this.minorRenderers,
    required this.callName,
    required this.callStatus,
    required this.callTimer,
    required this.isFrontCameraUsed,
    required this.isScreenSharingEnabled,
    required this.participantsMediaConfigs,
    required this.onRenderersChanged,
    required this.statsReportsManager,
  });

  @override
  State<SpeakerViewLayout> createState() {
    return _SpeakerViewLayoutState(
      primaryRenderer: primaryRenderer,
      minorRenderers: minorRenderers,
      primaryVideoFit: primaryVideoFit,
    );
  }
}

class _SpeakerViewLayoutState extends State<SpeakerViewLayout> {
  static final String TAG = 'SpeakerViewLayout';
  final SpeakersManager _speakersManager = SpeakersManager();

  MapEntry<int, RTCVideoRenderer>? _primaryRenderer;
  Map<int, RTCVideoRenderer> _minorRenderers;
  RTCVideoViewObjectFit _primaryVideoFit;
  bool _isPrimaryUserForciblySelected = false;

  _SpeakerViewLayoutState({
    required MapEntry<int, RTCVideoRenderer>? primaryRenderer,
    required Map<int, RTCVideoRenderer> minorRenderers,
    required RTCVideoViewObjectFit primaryVideoFit,
  })  : _primaryRenderer = primaryRenderer,
        _minorRenderers = minorRenderers,
        _primaryVideoFit = primaryVideoFit;

  @override
  void initState() {
    _speakersManager.init(widget.statsReportsManager, _onSpeakerChanged);
  }

  @override
  void didUpdateWidget(SpeakerViewLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    log("[didUpdateWidget]", TAG);
    _primaryRenderer = widget.primaryRenderer;
    _minorRenderers = widget.minorRenderers;
    _primaryVideoFit = widget.primaryVideoFit;
  }

  @override
  Widget build(BuildContext context) {
    var orientation = MediaQuery.of(context).orientation;
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
        buildCallInfoWidget(),
      ]),
    ));
  }

  void _onSpeakerChanged(int userId) {
    log('[_onSpeakerChanged] userId: $userId, currentUserId: ${widget.currentUserId}',
        TAG);
    if (userId == widget.currentUserId) return;

    if (canShowVideo(userId, _minorRenderers[userId]?.srcObject,
        widget.participantsMediaConfigs)) {
      setState(() {
        updatePrimaryUser(
          userId,
          false,
          widget.currentUserId,
          _primaryRenderer,
          _minorRenderers,
          widget.participantsMediaConfigs,
          onRenderersUpdated: (newPrimaryRenderer, newMinorRenderers) {
            widget.onRenderersChanged
                .call(newPrimaryRenderer, newMinorRenderers);
            _primaryRenderer = newPrimaryRenderer;
            _minorRenderers = newMinorRenderers;
            _isPrimaryUserForciblySelected = false;
          },
        );
      });
    }
  }

  List<Widget> renderSpeakerModeViews(Orientation orientation) {
    log("[renderSpeakerModeViews]", TAG);
    List<Widget> streamsExpanded = [];

    var primaryVideo = buildPrimaryVideoWidget();
    if (primaryVideo != null) {
      streamsExpanded.add(primaryVideo);
    }

    var minorItems = buildMinorVideoItems(orientation);
    if (minorItems != null) {
      streamsExpanded.add(minorItems);
    }

    return streamsExpanded;
  }

  buildPrimaryVideoWidget() {
    Widget? createPrimaryVideoView() {
      var primaryVideo;
      if (canShowVideo(_primaryRenderer?.key, _primaryRenderer?.value.srcObject,
          widget.participantsMediaConfigs)) {
        primaryVideo = Expanded(
          flex: 3,
          child: PrimaryVideo(
            renderer: _primaryRenderer!.value,
            objectFit: widget.primaryVideoFit,
            mirror: _primaryRenderer!.key == widget.currentUserId &&
                widget.isFrontCameraUsed &&
                !widget.isScreenSharingEnabled,
            onDoubleTap: () {
              setState(() {
                _primaryVideoFit = _primaryVideoFit ==
                        RTCVideoViewObjectFit.RTCVideoViewObjectFitCover
                    ? RTCVideoViewObjectFit.RTCVideoViewObjectFitContain
                    : RTCVideoViewObjectFit.RTCVideoViewObjectFitCover;
                widget.onPrimaryVideoFitChanged?.call(_primaryVideoFit);
              });
            },
          ),
        );
      }

      return primaryVideo;
    }

    var primaryVideoWidget;

    var minorUserWithEnabledVideo = getUserWithEnabledVideo(
        _minorRenderers, widget.currentUserId, widget.participantsMediaConfigs);

    if ((_primaryRenderer?.key != widget.currentUserId ||
            (_primaryRenderer?.key == widget.currentUserId &&
                (_isPrimaryUserForciblySelected ||
                    minorUserWithEnabledVideo == null))) &&
        canShowVideo(_primaryRenderer?.key, _primaryRenderer?.value.srcObject,
            widget.participantsMediaConfigs)) {
      primaryVideoWidget = createPrimaryVideoView();
    } else if (minorUserWithEnabledVideo != null) {
      updatePrimaryUser(
        minorUserWithEnabledVideo,
        true,
        widget.currentUserId,
        _primaryRenderer,
        _minorRenderers,
        widget.participantsMediaConfigs,
        onRenderersUpdated: (newPrimaryRenderer, newMinorRenderers) {
          widget.onRenderersChanged.call(newPrimaryRenderer, newMinorRenderers);
          _primaryRenderer = newPrimaryRenderer;
          _minorRenderers = newMinorRenderers;
        },
      );
      _isPrimaryUserForciblySelected = false;
      primaryVideoWidget = createPrimaryVideoView();
    }

    return primaryVideoWidget;
  }

  Widget? buildMinorVideoItems(Orientation orientation) {
    var itemHeight;
    var itemWidth;

    if (orientation == Orientation.portrait) {
      itemHeight = MediaQuery.of(context).size.height / 3 * 0.8;
      itemWidth = itemHeight / 3 * 4;
    } else {
      itemWidth = MediaQuery.of(context).size.width / 3 * 0.8;
      itemHeight = itemWidth / 4 * 3;
    }

    var videoItems = <Widget>[];

    _minorRenderers.forEach(
      (key, value) {
        if ((value.srcObject?.getVideoTracks().isNotEmpty ?? false) &&
            isUserCameraEnabled(key, widget.participantsMediaConfigs,
                defaultValue: true)) {
          videoItems.add(
            StreamBuilder<CubeMicLevelEvent>(
              stream: widget.statsReportsManager.micLevelStream
                  .where((event) => event.userId == key),
              builder: (context, snapshot) {
                var defaultBorderWidth = 4.0;
                var width = !snapshot.hasData
                    ? 0
                    : snapshot.data!.micLevel * defaultBorderWidth;

                return Padding(
                    padding: EdgeInsets.all(2),
                    child: Container(
                      margin: EdgeInsets.all(defaultBorderWidth),
                      decoration: ShapeDecoration(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.0),
                          side: BorderSide(
                              width: width.toDouble(),
                              color: Colors.green,
                              strokeAlign: 1.0),
                        ),
                      ),
                      child: MinorVideo(
                        width: itemWidth,
                        height: itemHeight,
                        renderer: value,
                        mirror: key == widget.currentUserId &&
                            widget.isFrontCameraUsed &&
                            !widget.isScreenSharingEnabled,
                        name: key == widget.currentUserId
                            ? 'Me'
                            : widget.participants
                                    .where((user) => user.id == key)
                                    .first
                                    .fullName ??
                                'Unknown',
                        onTap: () => setState(
                          () {
                            log("[onTap] userId: $key", TAG);
                            updatePrimaryUser(
                              key,
                              true,
                              widget.currentUserId,
                              _primaryRenderer,
                              _minorRenderers,
                              widget.participantsMediaConfigs,
                              onRenderersUpdated:
                                  (newPrimaryRenderer, newMinorRenderers) {
                                widget.onRenderersChanged.call(
                                    newPrimaryRenderer, newMinorRenderers);
                                _primaryRenderer = newPrimaryRenderer;
                                _minorRenderers = newMinorRenderers;
                              },
                            );
                            _isPrimaryUserForciblySelected = true;
                          },
                        ),
                      ),
                    ));
              },
            ),
          );
        }
      },
    );

    var minorVideoItems;

    if (videoItems.isNotEmpty) {
      var membersList = Expanded(
        flex: 1,
        child: ListView(
          scrollDirection: orientation == Orientation.landscape
              ? Axis.vertical
              : Axis.horizontal,
          children: videoItems,
        ),
      );

      minorVideoItems = membersList;
    }

    return minorVideoItems;
  }

  Widget buildCallInfoWidget() {
    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        margin: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 48,
        ),
        child: CallInfo(widget.callName, widget.callStatus, widget.callTimer),
      ),
    );
  }

  @override
  void dispose() {
    _speakersManager.dispose();
    super.dispose();
  }
}
