import 'dart:async';

class DurationTimer {
  int duration = 0;

  Timer? _durationTimer;
  StreamController<int> _durationStreamController =
      StreamController.broadcast();

  Stream<int> get durationStream => _durationStreamController.stream;

  start() {
    if (_durationTimer == null) {
      _durationTimer = Timer.periodic(Duration(seconds: 1), (timer) async {
        duration++;
        _durationStreamController.add(duration);
      });
    }
  }

  stop() {
    _durationTimer?.cancel();
    _durationTimer = null;
  }

  dispose() {
    _durationTimer?.cancel();
    _durationTimer = null;
    duration = 0;
  }
}
