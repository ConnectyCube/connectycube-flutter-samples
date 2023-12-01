import 'package:flutter/material.dart';

import 'package:connectycube_sdk/connectycube_sdk.dart';

import '../utils/duration_timer.dart';
import '../utils/media_utils.dart';
import 'call_info_widget.dart';
import 'minor_video_widget.dart';
import 'primary_video_widget.dart';

class PrivateCallLayout extends StatefulWidget {
  final MapEntry<int, RTCVideoRenderer>? primaryRenderer;
  final Map<int, RTCVideoRenderer> minorRenderers;
  final RTCVideoViewObjectFit primaryVideoFit;
  final Function(RTCVideoViewObjectFit newObjectFit)? onPrimaryVideoFitChanged;
  final int currentUserId;
  final String callName;
  final String callStatus;
  final DurationTimer callTimer;
  final bool isFrontCameraUsed;
  final bool isScreenSharingEnabled;
  final Map<int, Map<String, bool>> participantsMediaConfigs;
  final WidgetPosition minorWidgetInitialPosition;
  final Function(WidgetPosition newPosition)? onMinorVideoPositionChanged;
  final Function(MapEntry<int, RTCVideoRenderer>? primaryRenderer,
      Map<int, RTCVideoRenderer> minorRenderers) onRenderersChanged;

  PrivateCallLayout({
    super.key,
    required this.currentUserId,
    required this.primaryRenderer,
    required this.primaryVideoFit,
    this.onPrimaryVideoFitChanged,
    required this.minorRenderers,
    required this.callName,
    required this.callStatus,
    required this.callTimer,
    required this.minorWidgetInitialPosition,
    required this.isFrontCameraUsed,
    required this.isScreenSharingEnabled,
    required this.participantsMediaConfigs,
    this.onMinorVideoPositionChanged,
    required this.onRenderersChanged,
  });

  @override
  State<PrivateCallLayout> createState() {
    return _PrivateCallLayoutState(
      primaryRenderer: primaryRenderer,
      minorRenderers: minorRenderers,
      primaryVideoFit: primaryVideoFit,
      minorWidgetInitialPosition: minorWidgetInitialPosition,
    );
  }
}

class _PrivateCallLayoutState extends State<PrivateCallLayout> {
  static final String TAG = 'PrivateCallLayout';

  MapEntry<int, RTCVideoRenderer>? _primaryRenderer;
  Map<int, RTCVideoRenderer> _minorRenderers;
  RTCVideoViewObjectFit _primaryVideoFit;
  bool _isPrimaryUserForciblySelected = false;
  WidgetPosition _minorWidgetInitialPosition;
  Offset _minorWidgetOffset = Offset(0, 0);
  bool _isWidgetMoving = false;

  _PrivateCallLayoutState({
    required MapEntry<int, RTCVideoRenderer>? primaryRenderer,
    required Map<int, RTCVideoRenderer> minorRenderers,
    required RTCVideoViewObjectFit primaryVideoFit,
    required WidgetPosition minorWidgetInitialPosition,
  })  : _primaryRenderer = primaryRenderer,
        _minorRenderers = minorRenderers,
        _primaryVideoFit = primaryVideoFit,
        _minorWidgetInitialPosition = minorWidgetInitialPosition;

  @override
  void didUpdateWidget(PrivateCallLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    log("[didUpdateWidget]", TAG);
    _primaryRenderer = widget.primaryRenderer;
    _minorRenderers = widget.minorRenderers;
    _primaryVideoFit = widget.primaryVideoFit;
    _minorWidgetInitialPosition = widget.minorWidgetInitialPosition;
  }

  @override
  Widget build(BuildContext context) {
    var orientation = MediaQuery.of(context).orientation;
    log("[build]", TAG);

    List<Widget> children = [];

    var primaryVideo = buildPrimaryVideoWidget();
    if (primaryVideo != null) {
      children.add(primaryVideo);
    }

    children.add(buildCallInfoWidget());

    var minorVideo = buildMinorVideoWidget(orientation);
    if (minorVideo != null) {
      children.add(minorVideo);
    }

    return Stack(children: children);
  }

  Widget? buildPrimaryVideoWidget() {
    Widget? createPrimaryVideoWidget() {
      if (canShowVideo(_primaryRenderer?.key, _primaryRenderer?.value.srcObject,
          widget.participantsMediaConfigs)) {
        return PrimaryVideo(
          renderer: _primaryRenderer!.value,
          objectFit: _primaryVideoFit,
          mirror: _primaryRenderer?.key == widget.currentUserId &&
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
        );
      }

      return null;
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
      primaryVideoWidget = createPrimaryVideoWidget();
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

          _isPrimaryUserForciblySelected = false;
          primaryVideoWidget = createPrimaryVideoWidget();
        },
      );
    }

    return primaryVideoWidget;
  }

  Widget buildCallInfoWidget() {
    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        margin: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 48,
        ),
        child: CallInfo(
          widget.callName,
          widget.callStatus,
          widget.callTimer,
        ),
      ),
    );
  }

  Widget? buildMinorVideoWidget(Orientation orientation) {
    var width = calculateMinorVideoViewWidth(context, orientation);
    var height = calculateMinorVideoViewHeight(context, orientation);

    var videoItems = <Widget>[];

    _minorRenderers.forEach(
      (key, value) {
        if ((value.srcObject?.getVideoTracks().isNotEmpty ?? false) &&
            isUserCameraEnabled(key, widget.participantsMediaConfigs,
                defaultValue: true)) {
          videoItems.add(
            MinorVideo(
              width: width,
              height: height,
              renderer: value,
              mirror: key == widget.currentUserId &&
                  widget.isFrontCameraUsed &&
                  !widget.isScreenSharingEnabled,
              onPanUpdate: (details) =>
                  _onPanUpdate(context, details, _minorWidgetOffset),
              onPanEnd: (details) => _onPanEnd(context, details),
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
                      widget.onRenderersChanged
                          .call(newPrimaryRenderer, newMinorRenderers);
                      _primaryRenderer = newPrimaryRenderer;
                      _minorRenderers = newMinorRenderers;
                    },
                  );
                  _isPrimaryUserForciblySelected = true;
                },
              ),
            ),
          );
        }
      },
    );

    if (videoItems.isEmpty) return null;

    var minorItem = videoItems.firstOrNull;

    if (minorItem != null) {
      var widgetOffset =
          getOffsetForPosition(context, _minorWidgetInitialPosition);

      if (_isWidgetMoving) {
        widgetOffset = _minorWidgetOffset;
      }

      return Positioned(
        top: widgetOffset.dy - height / 2,
        left: widgetOffset.dx - width / 2,
        child: minorItem,
      );
    }

    return minorItem;
  }

  void _onPanUpdate(
      BuildContext context, DragUpdateDetails details, Offset offset) {
    log('_onPanUpdate', TAG);

    setState(() {
      _isWidgetMoving = true;
      _minorWidgetOffset = details.globalPosition;
    });
  }

  void _onPanEnd(BuildContext context, DragEndDetails details) {
    log('_onPanEnd', TAG);

    setState(() {
      _isWidgetMoving = false;
      _minorWidgetInitialPosition =
          calculateMinorVideoViewPosition(context, _minorWidgetOffset);
      widget.onMinorVideoPositionChanged?.call(_minorWidgetInitialPosition);
    });
  }
}

double calculateMinorVideoViewWidth(
    BuildContext context, Orientation orientation) {
  return orientation == Orientation.portrait
      ? MediaQuery.of(context).size.width / 3
      : MediaQuery.of(context).size.width / 4;
}

double calculateMinorVideoViewHeight(
    BuildContext context, Orientation orientation) {
  return orientation == Orientation.portrait
      ? MediaQuery.of(context).size.height / 4
      : MediaQuery.of(context).size.height / 2.5;
}

WidgetPosition calculateMinorVideoViewPosition(
    BuildContext context, Offset initialPosition) {
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

Offset getOffsetForPosition(BuildContext context, WidgetPosition position) {
  var orientation = MediaQuery.of(context).orientation;

  var width = calculateMinorVideoViewWidth(context, orientation);
  var height = calculateMinorVideoViewHeight(context, orientation);

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

enum WidgetPosition { topLeft, topRight, bottomLeft, bottomRight }
