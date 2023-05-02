import 'dart:async';
import 'dart:collection';

import 'package:connectycube_sdk/connectycube_sdk.dart';

class SpeakersManager {
  Timer? _processSpeakerTimer;
  Map<int, double> _speakers = {};

  void init(CubeStatsReportsManager statsReportsManager,
      SpeakerChangedCallback callBack) {
    statsReportsManager.micLevelStream.listen((event) {
      if (_speakers[event.userId] == null) {
        _speakers[event.userId] = 0.0;
      }

      _speakers[event.userId] = _speakers[event.userId]! + event.micLevel;
    });

    _processSpeakerTimer = Timer.periodic(Duration(seconds: 2), (timer) {
      log('[calculate speaker]', 'SpeakersManager');

      if (_speakers.isEmpty) return;

      var sortedByValueMap = new SplayTreeMap<int, double>.from(
          _speakers, (k1, k2) => _speakers[k1]!.compareTo(_speakers[k2]!));

      if (sortedByValueMap[sortedByValueMap.lastKey()] == 0) return;

      int speakerId = sortedByValueMap.lastKey()!;

      log('[calculate speaker] speaker is $speakerId', 'SpeakersManager');

      callBack.call(speakerId);

      _speakers.clear();
    });
  }

  void dispose() {
    _processSpeakerTimer?.cancel();
  }
}

typedef SpeakerChangedCallback(int userId);
