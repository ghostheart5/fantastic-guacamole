import 'dart:async';

typedef SyncCallback = Future<void> Function();

class BackgroundSyncHandler {
  // ignore: prefer_initializing_formals — public param 'onSync' assigns to private '_onSync'
  BackgroundSyncHandler({SyncCallback? onSync}) : _onSync = onSync;

  final SyncCallback? _onSync;
  Timer? _timer;
  DateTime? _lastSyncAt;

  static const Duration _syncInterval = Duration(minutes: 15);

  bool get isScheduled => _timer?.isActive ?? false;
  DateTime? get lastSyncAt => _lastSyncAt;

  Future<void> scheduleSync() async {
    _timer?.cancel();
    _timer = Timer.periodic(_syncInterval, (_) => _runSync());
  }

  Future<void> flush() async {
    await _runSync();
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _runSync() async {
    final callback = _onSync;
    if (callback == null) return;
    try {
      await callback();
      _lastSyncAt = DateTime.now();
    } catch (_) {
      // Sync failures are non-fatal — next scheduled tick will retry
    }
  }
}
