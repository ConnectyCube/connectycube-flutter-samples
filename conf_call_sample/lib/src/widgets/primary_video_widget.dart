import 'package:flutter/material.dart';

import 'package:connectycube_sdk/connectycube_sdk.dart';

class PrimaryVideo extends StatelessWidget {
  final RTCVideoRenderer renderer;
  final RTCVideoViewObjectFit objectFit;
  final bool mirror;
  final Function()? onDoubleTap;

  const PrimaryVideo({
    super.key,
    required this.renderer,
    required this.objectFit,
    required this.mirror,
    this.onDoubleTap,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      GestureDetector(
        onDoubleTap: onDoubleTap,
        child: RTCVideoView(
          renderer,
          objectFit: objectFit,
          mirror: mirror,
        ),
      ),
    ]);
  }
}
