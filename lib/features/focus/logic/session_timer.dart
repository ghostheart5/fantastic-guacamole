import 'dart:async';

class SessionTimer {
  SessionTimer({required this.totalSeconds, required this.onTick, this.onDone});

  final int totalSeconds;
  final void Function(int remainingSeconds) onTick;
  final void Function()? onDone;

  Timer? _timer;
  int _remaining = 0;

  int get remainingSeconds => _remaining;
  bool get isRunning => _timer?.isActive ?? false;

  void start() {
    stop();
    _remaining = totalSeconds;
    onTick(_remaining);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _remaining -= 1;
      if (_remaining <= 0) {
        stop();
        onTick(0);
        onDone?.call();
        return;
      }
      onTick(_remaining);
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() {
    stop();
  }
}
