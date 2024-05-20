import 'package:cached_video_player_plus/cached_video_player_plus.dart';
import 'package:flutter/material.dart';

class FullVideoScreen extends StatefulWidget {
  final String url;
  final CachedVideoPlayerPlusController? controller;

  const FullVideoScreen({super.key, required this.url, this.controller});

  @override
  State createState() => FullVideoScreenState();
}

class FullVideoScreenState extends State<FullVideoScreen> {
  late CachedVideoPlayerPlusController controller;

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) {
      controller = CachedVideoPlayerPlusController.networkUrl(
          Uri.parse(widget.url),
          httpHeaders: {
            'Cache-Control': 'max-age=${30 * 24 * 60 * 60}',
          });
    } else {
      controller = widget.controller!;
    }
    controller.addListener(() {
      if (mounted) {
        setState(() {
          if (controller.value.duration != Duration.zero &&
              controller.value.position == controller.value.duration) {
            controller.seekTo(Duration.zero).then((value) {
              controller.pause();
            });
          }
        });
      }
    });

    if (!controller.value.isInitialized) {
      controller.initialize().then((_) {});
    }
  }

  @override
  Widget build(BuildContext context) {
    var orientation = MediaQuery.of(context).orientation;
    var deviceWidth = MediaQuery.of(context).size.width -
        (MediaQuery.of(context).padding.left +
            MediaQuery.of(context).padding.right);
    var deviceHeight = MediaQuery.of(context).size.height -
        (MediaQuery.of(context).padding.top +
            MediaQuery.of(context).padding.bottom);

    var videoAspectRatio = controller.value.aspectRatio;

    double widgetWidth;
    double widgetHeight;

    if (orientation == Orientation.portrait) {
      widgetWidth = deviceWidth;
      widgetHeight = (widgetWidth ~/ videoAspectRatio).toDouble();
    } else {
      widgetHeight = deviceHeight;
      widgetWidth = widgetHeight * videoAspectRatio;
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: SizedBox(
              width: widgetWidth,
              height: widgetHeight,
              child: CachedVideoPlayerPlus(controller),
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              height: 86,
              child: AppBar(
                backgroundColor: Colors.black38,
              ),
            ),
          ),
          Align(
            alignment: Alignment.center,
            child: FloatingActionButton(
              heroTag: "PlayPauseVideo",
              onPressed: controller.value.isPlaying
                  ? controller.pause
                  : controller.play,
              backgroundColor: Colors.black38,
              elevation: 0.0,
              child: Icon(controller.value.isPlaying
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              margin:
                  const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
              child: VideoProgressIndicator(
                controller,
                allowScrubbing: true,
                colors: VideoProgressColors(
                    playedColor: Colors.green,
                    bufferedColor: Colors.green.shade100),
              ),
            ),
          ),
          Visibility(
            visible: controller.value.isBuffering,
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Container(
                margin: const EdgeInsets.only(left: 8, bottom: 32),
                child: const Text(
                  'Buffering...',
                  style: TextStyle(
                    fontSize: 12,
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
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      controller.dispose();
    }
    super.dispose();
  }
}
