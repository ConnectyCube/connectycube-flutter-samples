import 'dart:async';

class DurationTimer {
  int _durationSec = 0;

  Timer? _durationTimer;
  final StreamController<int> _durationStreamController =
      StreamController.broadcast();

  Stream<int> get durationStream => _durationStreamController.stream;

  start() {
    _durationTimer ??=
        Timer.periodic(const Duration(seconds: 1), (timer) async {
      _durationSec++;
      _durationStreamController.add(_durationSec);
    });
  }

  stop() {
    _durationTimer?.cancel();
    _durationTimer = null;
    _durationSec = 0;
  }
}
