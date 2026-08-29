import 'dart:async';

import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/state/services/cache_cleanup_service.dart';
import 'package:fantastic_guacamole/state/services/expired_session_cleanup.dart';
import 'package:fantastic_guacamole/state/services/orphan_data_cleanup.dart';
import 'package:fantastic_guacamole/state/services/retention_policy.dart';
import 'package:fantastic_guacamole/state/services/stale_notification_cleanup.dart';

class DataHygieneReport {
  const DataHygieneReport({
    required this.cacheItemsRemoved,
    required this.orphansRemoved,
    required this.expiredSessionRemoved,
    required this.staleNotificationsRemoved,
  });

  final int cacheItemsRemoved;
  final int orphansRemoved;
  final bool expiredSessionRemoved;
  final int staleNotificationsRemoved;

  int get totalActions =>
      cacheItemsRemoved +
      orphansRemoved +
      staleNotificationsRemoved +
      (expiredSessionRemoved ? 1 : 0);
}

class DataHygieneScheduler {
  DataHygieneScheduler({
    required this._cacheCleanup,
    required this._orphanCleanup,
    required this._expiredSessionCleanup,
    required this._staleNotificationCleanup,
    required this._retentionPolicy,
  }) : _runCacheCleanupOverride = null,
       _runOrphanCleanupOverride = null,
       _runExpiredSessionCleanupOverride = null,
       _runStaleNotificationCleanupOverride = null;

  factory DataHygieneScheduler.forTesting({
    required Future<int> Function() runCacheCleanup,
    required Future<int> Function() runOrphanCleanup,
    required Future<bool> Function() runExpiredSessionCleanup,
    required Future<int> Function() runStaleNotificationCleanup,
    required RetentionPolicy retentionPolicy,
  }) => DataHygieneScheduler._withOperations(
    runCacheCleanup: runCacheCleanup,
    runOrphanCleanup: runOrphanCleanup,
    runExpiredSessionCleanup: runExpiredSessionCleanup,
    runStaleNotificationCleanup: runStaleNotificationCleanup,
    retentionPolicy: retentionPolicy,
  );

  DataHygieneScheduler._withOperations({
    required Future<int> Function() runCacheCleanup,
    required Future<int> Function() runOrphanCleanup,
    required Future<bool> Function() runExpiredSessionCleanup,
    required Future<int> Function() runStaleNotificationCleanup,
    required this._retentionPolicy,
  }) : _cacheCleanup = null,
       _orphanCleanup = null,
       _expiredSessionCleanup = null,
       _staleNotificationCleanup = null,
       _runCacheCleanupOverride = runCacheCleanup,
       _runOrphanCleanupOverride = runOrphanCleanup,
       _runExpiredSessionCleanupOverride = runExpiredSessionCleanup,
       _runStaleNotificationCleanupOverride = runStaleNotificationCleanup;

  final CacheCleanupService? _cacheCleanup;
  final OrphanDataCleanup? _orphanCleanup;
  final ExpiredSessionCleanup? _expiredSessionCleanup;
  final StaleNotificationCleanup? _staleNotificationCleanup;
  final RetentionPolicy _retentionPolicy;
  final Future<int> Function()? _runCacheCleanupOverride;
  final Future<int> Function()? _runOrphanCleanupOverride;
  final Future<bool> Function()? _runExpiredSessionCleanupOverride;
  final Future<int> Function()? _runStaleNotificationCleanupOverride;

  Timer? _timer;
  bool _running = false;
  Future<DataHygieneReport>? _activeRun;

  bool get isRunning => _running;

  void start() {
    if (_running) {
      return;
    }
    _running = true;
    _timer = Timer.periodic(_retentionPolicy.hygieneInterval, (_) {
      unawaited(_runInBackground());
    });
    unawaited(_runInBackground());
  }

  void pause() {
    _running = false;
    _timer?.cancel();
    _timer = null;
  }

  void shutdown() {
    pause();
  }

  Future<DataHygieneReport> runNow() {
    final Future<DataHygieneReport>? activeRun = _activeRun;
    if (activeRun != null) {
      return activeRun;
    }

    late final Future<DataHygieneReport> nextRun;
    nextRun = _runOnce().whenComplete(() {
      if (identical(_activeRun, nextRun)) {
        _activeRun = null;
      }
    });
    _activeRun = nextRun;
    return nextRun;
  }

  Future<void> _runInBackground() async {
    try {
      await runNow();
    } on Object catch (error, stackTrace) {
      Logger.errorCategory(
        'DataHygiene',
        'Cleanup tick failed; a later scheduled run will retry.',
        error,
        stackTrace,
      );
    }
  }

  Future<DataHygieneReport> _runOnce() async {
    final int cache = await (_runCacheCleanupOverride ?? _cacheCleanup!.run)();
    final int orphans =
        await (_runOrphanCleanupOverride ?? _orphanCleanup!.run)();
    final bool expiredSession =
        await (_runExpiredSessionCleanupOverride ??
            _expiredSessionCleanup!.run)();
    final int stale =
        await (_runStaleNotificationCleanupOverride ??
            _staleNotificationCleanup!.run)();

    final DataHygieneReport report = DataHygieneReport(
      cacheItemsRemoved: cache,
      orphansRemoved: orphans,
      expiredSessionRemoved: expiredSession,
      staleNotificationsRemoved: stale,
    );

    Logger.log(
      'DataHygiene',
      'Cleanup tick complete. actions=${report.totalActions} '
          '(cache=$cache, orphans=$orphans, expiredSession=$expiredSession, staleNotifications=$stale)',
    );

    return report;
  }
}
