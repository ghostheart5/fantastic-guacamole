import 'dart:async';

import 'package:flutter/foundation.dart';

class SystemScheduler {
  bool _running = false;
  Timer? _offlineSyncTimer;
  Timer? _aiPrecomputeTimer;

  bool get isRunning => _running;

  /// Wired by [NavigationShell] to replay the offline queue on each tick.
  VoidCallback? onSyncOfflineQueue;

  /// Wired by [NavigationShell] to invalidate AI providers on each tick.
  VoidCallback? onPrecomputeAI;

  void resume() {
    if (_running) return;
    _running = true;
    _offlineSyncTimer = Timer.periodic(const Duration(minutes: 15), (_) {
      if (_running) onSyncOfflineQueue?.call();
    });
    _aiPrecomputeTimer = Timer.periodic(const Duration(minutes: 20), (_) {
      if (_running) onPrecomputeAI?.call();
    });
  }

  void pause() {
    _running = false;
    _offlineSyncTimer?.cancel();
    _aiPrecomputeTimer?.cancel();
    _offlineSyncTimer = null;
    _aiPrecomputeTimer = null;
  }

  void shutdown() {
    pause();
  }
}
