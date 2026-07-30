import 'dart:async';

class Throttle {
  Throttle(this.delay);

  final Duration delay;
  Timer? _timer;
  bool _ready = true;

  bool get isReady => _ready;

  void run(void Function() action) {
    if (!_ready) return;
    _ready = false;
    action();
    _timer?.cancel();
    _timer = Timer(delay, () => _ready = true);
  }

  Future<void> runAsync(Future<void> Function() action) async {
    if (!_ready) return;
    _ready = false;
    try {
      await action();
    } finally {
      _timer?.cancel();
      _timer = Timer(delay, () => _ready = true);
    }
  }

  void reset() {
    _timer?.cancel();
    _ready = true;
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}
