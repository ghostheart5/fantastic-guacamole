import 'dart:async';

import 'package:flutter/foundation.dart';

class SystemScheduler {
  bool _running = false;
  Timer? _offlineSyncTimer;

  bool get isRunning => _running;

  /// Wired by [NavigationShell] to replay the offline queue on each tick.
  VoidCallback? onSyncOfflineQueue;

  void resume() {
    if (_running) return;
    _running = true;
    _offlineSyncTimer = Timer.periodic(const Duration(minutes: 15), (_) {
      if (_running) onSyncOfflineQueue?.call();
    });
  }

  void pause() {
    _running = false;
    _offlineSyncTimer?.cancel();
    _offlineSyncTimer = null;
  }

  void shutdown() {
    pause();
  }
}
