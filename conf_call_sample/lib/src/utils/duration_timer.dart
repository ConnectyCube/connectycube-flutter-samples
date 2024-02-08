import 'dart:async';

class DurationTimer {
  int _durationSec = 0;

  Timer? _durationTimer;
  StreamController<int> _durationStreamController =
      StreamController.broadcast();

  Stream<int> get durationStream => _durationStreamController.stream;

  start() {
    if (_durationTimer == null) {
      _durationTimer = Timer.periodic(Duration(seconds: 1), (timer) async {
        _durationSec++;
        _durationStreamController.add(_durationSec);
      });
    }
  }

  stop() {
    _durationTimer?.cancel();
    _durationTimer = null;
    _durationSec = 0;
  }
}
