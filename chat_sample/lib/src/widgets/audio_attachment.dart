import 'dart:math';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../utils/string_utils.dart';

class AudioAttachment extends StatefulWidget {
  final int duration;
  final String source;
  final Color accentColor;

  const AudioAttachment({
    super.key,
    required this.source,
    required this.duration,
    this.accentColor = Colors.blue,
  });

  @override
  State<StatefulWidget> createState() {
    return AudioAttachmentState();
  }
}

class AudioAttachmentState extends State<AudioAttachment> {
  final String tag = 'AudioAttachment';

  final AudioPlayer player = AudioPlayer();

  @override
  void initState() {
    super.initState();

    player.setUrl(widget.source, preload: false);
    player.positionStream.listen((duration) {
      if (duration.inMilliseconds == player.duration?.inMilliseconds) {
        player.seek(const Duration(milliseconds: 0));
        player.pause();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 4),
      height: 70,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: () {
              startStopPlayer();
            },
            child: AbsorbPointer(
              child: Container(
                width: 40,
                height: 40,
                decoration: ShapeDecoration(
                  color: widget.accentColor,
                  shape: const CircleBorder(),
                ),
                child: StreamBuilder<PlayerState>(
                  stream: player.playerStateStream,
                  builder: (context, snapshot) {
                    return Icon(
                      snapshot.data?.playing ?? false
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.white,
                    );
                  },
                ),
              ),
            ),
          ),
          StreamBuilder<Duration>(
              stream: player.positionStream,
              builder: (context, snapshot) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      height: 24,
                      child: Slider(
                          min: 0,
                          max: max(
                              player.duration?.inMilliseconds.toDouble() ?? 1.0,
                              player.position.inMilliseconds.toDouble()),
                          activeColor: widget.accentColor,
                          inactiveColor: widget.accentColor.withAlpha(100),
                          value: snapshot.data?.inMilliseconds.toDouble() ?? 0,
                          onChanged: onPositionChanged),
                    ),
                    Row(children: [
                      Text(
                        '${formatHHMMSS(snapshot.data?.inSeconds ?? 0)}/${formatHHMMSS(player.duration?.inSeconds ?? widget.duration ~/ 1000)}',
                        style: TextStyle(color: widget.accentColor),
                      ),
                      StreamBuilder<ProcessingState>(
                          stream: player.processingStateStream,
                          builder: (context, snapshot) {
                            return Visibility(
                                visible:
                                    snapshot.data == ProcessingState.loading,
                                child: Container(
                                    margin: const EdgeInsets.only(left: 4),
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(
                                      color: widget.accentColor,
                                      strokeWidth: 2,
                                    )));
                          })
                    ])
                  ],
                );
              })
        ],
      ),
    );
  }

  void startStopPlayer() {
    if (player.playing) {
      player.pause().then((_) {
        setState(() {});
      });
    } else {
      setState(() {
        player.play();
      });
    }
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }

  void onPositionChanged(double value) {
    player.seek(Duration(milliseconds: value.toInt()));
  }
}
