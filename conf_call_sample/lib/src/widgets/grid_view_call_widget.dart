import 'package:flutter/material.dart';

import 'package:connectycube_sdk/connectycube_sdk.dart';

import '../utils/media_utils.dart';
import 'minor_video_widget.dart';

class GridViewLayout extends StatefulWidget {
  final MapEntry<int, RTCVideoRenderer>? primaryRenderer;
  final Map<int, RTCVideoRenderer> minorRenderers;
  final int currentUserId;
  final List<CubeUser> participants;
  final bool isFrontCameraUsed;
  final bool isScreenSharingEnabled;
  final Map<int, Map<String, bool>> participantsMediaConfigs;
  final Function(MapEntry<int, RTCVideoRenderer>? primaryRenderer,
      Map<int, RTCVideoRenderer> minorRenderers) onRenderersChanged;
  final CubeStatsReportsManager statsReportsManager;
  final Future<String> Function(int userId)? getUserName;

  GridViewLayout({
    super.key,
    required this.currentUserId,
    required this.participants,
    required this.primaryRenderer,
    required this.minorRenderers,
    required this.isFrontCameraUsed,
    required this.isScreenSharingEnabled,
    required this.participantsMediaConfigs,
    required this.onRenderersChanged,
    required this.statsReportsManager,
    this.getUserName,
  });

  @override
  State<GridViewLayout> createState() {
    return _GridViewLayoutState(
      primaryRenderer: primaryRenderer,
      minorRenderers: minorRenderers,
    );
  }
}

class _GridViewLayoutState extends State<GridViewLayout> {
  static final String TAG = 'GridViewLayout';

  MapEntry<int, RTCVideoRenderer>? _primaryRenderer;
  Map<int, RTCVideoRenderer> _minorRenderers;

  _GridViewLayoutState({
    required MapEntry<int, RTCVideoRenderer>? primaryRenderer,
    required Map<int, RTCVideoRenderer> minorRenderers,
  })  : _primaryRenderer = primaryRenderer,
        _minorRenderers = minorRenderers;

  @override
  void didUpdateWidget(GridViewLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    _primaryRenderer = widget.primaryRenderer;
    _minorRenderers = widget.minorRenderers;
  }

  @override
  Widget build(BuildContext context) {
    var orientation = MediaQuery.of(context).orientation;
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
        Map.fromEntries([..._minorRenderers.entries]);
    if (_primaryRenderer != null) {
      allRenderers.addEntries([_primaryRenderer!]);
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
    var videoItems = <Widget>[];

    renderers.forEach(
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

                return Container(
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
                    getUserName: widget.getUserName?.call(key),
                  ),
                );
              },
            ),
          );
        }
      },
    );

    return videoItems;
  }
}
