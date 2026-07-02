import 'package:fantastic_guacamole/features/focus/logic/session_timer.dart';

class FocusServices {
  const FocusServices();

  SessionTimer createTimer({
    required int totalSeconds,
    required void Function(int remainingSeconds) onTick,
    void Function()? onDone,
  }) {
    return SessionTimer(
      totalSeconds: totalSeconds,
      onTick: onTick,
      onDone: onDone,
    );
  }
}
