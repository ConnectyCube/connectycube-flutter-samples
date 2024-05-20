import 'dart:async';

class DurationTimer {
  int duration = 0;

  Timer? _durationTimer;
  final StreamController<int> _durationStreamController =
      StreamController.broadcast();

  Stream<int> get durationStream => _durationStreamController.stream;

  start() {
    _durationTimer ??=
        Timer.periodic(const Duration(seconds: 1), (timer) async {
      duration++;
      _durationStreamController.add(duration);
    });
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
