import 'dart:async';

import 'package:fantastic_guacamole/core/utils/throttle.dart';

class AppTap {
  AppTap({
    this.doubleTapDelay = const Duration(milliseconds: 250),
    this.longPressDelay = const Duration(milliseconds: 500),
    Duration throttleDelay = const Duration(milliseconds: 300),
    this.debounceDelay = const Duration(milliseconds: 250),
  }) : _throttle = Throttle(throttleDelay);

  final Duration doubleTapDelay;
  final Duration longPressDelay;
  final Duration debounceDelay;

  final Throttle _throttle;
  Timer? _doubleTapTimer;
  Timer? _longPressTimer;
  Timer? _debounceTimer;
  bool _waitingForSecondTap = false;

  void onTap({required void Function() singleTap, void Function()? doubleTap}) {
    if (_waitingForSecondTap) {
      _waitingForSecondTap = false;
      _doubleTapTimer?.cancel();
      doubleTap?.call();
      return;
    }

    _waitingForSecondTap = true;
    _doubleTapTimer = Timer(doubleTapDelay, () {
      if (_waitingForSecondTap) singleTap();
      _waitingForSecondTap = false;
    });
  }

  void onLongPress(void Function() action) {
    _longPressTimer?.cancel();
    _longPressTimer = Timer(longPressDelay, action);
  }

  void cancelLongPress() => _longPressTimer?.cancel();

  void onThrottledTap(void Function() action) => _throttle.run(action);

  void onDebouncedTap(void Function() action) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounceDelay, action);
  }

  void dispose() {
    _doubleTapTimer?.cancel();
    _longPressTimer?.cancel();
    _debounceTimer?.cancel();
    _throttle.dispose();
  }
}
