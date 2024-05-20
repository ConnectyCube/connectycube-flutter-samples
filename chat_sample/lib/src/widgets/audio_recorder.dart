import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart' as record;

import '../utils/consts.dart';
import '../utils/duration_timer.dart';
import '../utils/string_utils.dart';

class AudioRecorder extends StatefulWidget {
  final Function() onClose;
  final Function(
          String audioFilePath, String mimeType, String fileName, int duration)
      onAccept;

  const AudioRecorder({
    super.key,
    required this.onClose,
    required this.onAccept,
  });

  @override
  State<StatefulWidget> createState() {
    return AudioRecorderState();
  }
}

class AudioRecorderState extends State<AudioRecorder> {
  final String tag = 'AudioRecorder';
  final AudioPlayer player = AudioPlayer();
  final record.AudioRecorder recorder = record.AudioRecorder();
  final DurationTimer timer = DurationTimer();
  bool isRecording = false;
  bool isMicAwaiting = false;

  String? path;
  String? fileName;
  String? mimeType;

  @override
  void initState() {
    super.initState();
    player.setLoopMode(LoopMode.one);
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        // width: 228,
        padding: const EdgeInsets.all(4.0),
        height: 48,
        decoration: BoxDecoration(
            color: greyColor2, borderRadius: BorderRadius.circular(8.0)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Visibility(
              visible: player.audioSource != null,
              child: IconButton(
                splashRadius: 20,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                constraints: const BoxConstraints(),
                icon: Icon(
                  player.playing
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  color: Colors.green,
                ),
                onPressed: startStopPlayer,
              ),
            ),
            const SizedBox(
              width: 4,
            ),
            Row(children: [
              Visibility(
                visible: player.audioSource != null,
                child: StreamBuilder<Duration?>(
                  stream: player.positionStream,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const SizedBox.shrink();
                    }

                    return Text(
                      '${formatHHMMSS(snapshot.data!.inSeconds)}/',
                    );
                  },
                ),
              ),
              StreamBuilder<int>(
                  stream: timer.durationStream,
                  builder: (context, snapshot) {
                    return Text(
                      snapshot.hasData ? formatHHMMSS(snapshot.data!) : '00:00',
                    );
                  }),
            ]),
            Visibility(
              visible: path == null && !isMicAwaiting,
              child: IconButton(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                constraints: const BoxConstraints(),
                splashRadius: 20,
                icon: Icon(isRecording
                    ? Icons.stop_circle_rounded
                    : Icons.fiber_manual_record),
                color: Colors.red,
                onPressed: () {
                  startStopRecording();
                },
              ),
            ),
            Visibility(
              visible: isMicAwaiting,
              child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 14,
                  height: 14,
                  child: const CircularProgressIndicator(
                    color: Colors.red,
                    strokeWidth: 2,
                  )),
            ),
            Visibility(
              visible: path != null,
              child: IconButton(
                splashRadius: 20,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.check_rounded),
                color: Colors.blue,
                onPressed: () {
                  widget.onAccept.call(
                    path!,
                    mimeType ?? '',
                    fileName ?? '',
                    player.duration?.inMilliseconds ?? timer.duration * 1000,
                  );
                },
              ),
            ),
            IconButton(
              splashRadius: 20,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              constraints: const BoxConstraints(),
              icon: const Icon(Icons.close),
              color: Colors.red,
              onPressed: () {
                recorder.stop();
                player.stop();
                widget.onClose.call();
              },
            ),
          ],
        ),
      ),
    );
  }

  void startStopPlayer() {
    if (player.playing) {
      setState(() {
        player.pause();
      });
    } else if (path != null) {
      setState(() {
        player.play().then((_) {
          setState(() {});
        });
      });
    }
  }

  @override
  void dispose() {
    player.dispose();
    recorder.dispose();
    timer.dispose();
    super.dispose();
  }

  void startStopRecording() {
    if (!isRecording) {
      setState(() {
        isMicAwaiting = true;
      });
      recorder.hasPermission().then((hasPermission) {
        if (hasPermission) {
          setState(() {
            isMicAwaiting = false;
            isRecording = !isRecording;

            var getPathFeature = kIsWeb
                ? Future.value('')
                : getApplicationCacheDirectory().then((directory) {
                    return directory.path;
                  });

            getPathFeature.then((path) {
              fileName = 'record_${DateTime.now().millisecondsSinceEpoch}.wav';
              mimeType = 'audio/wav';
              timer.start();
              recorder.start(
                  const record.RecordConfig(encoder: record.AudioEncoder.wav),
                  path: '$path/$fileName');
            });
          });
        } else {
          setState(() {
            isMicAwaiting = false;
          });
          Fluttertoast.showToast(
              msg: 'Permission to use the microphone was not granted');
        }
      });
    } else {
      recorder.stop().then((filePath) {
        timer.stop();
        setState(() {
          isRecording = !isRecording;

          if (filePath != null) {
            path = filePath;

            if (!kIsWeb) {
              player.setFilePath(filePath);
            }
          }
        });
      });
    }
  }
}
