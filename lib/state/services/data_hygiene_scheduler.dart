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
  });

  final CacheCleanupService _cacheCleanup;
  final OrphanDataCleanup _orphanCleanup;
  final ExpiredSessionCleanup _expiredSessionCleanup;
  final StaleNotificationCleanup _staleNotificationCleanup;
  final RetentionPolicy _retentionPolicy;

  Timer? _timer;
  bool _running = false;

  bool get isRunning => _running;

  void start() {
    if (_running) {
      return;
    }
    _running = true;
    _timer = Timer.periodic(_retentionPolicy.hygieneInterval, (_) {
      unawaited(runNow());
    });
    unawaited(runNow());
  }

  void pause() {
    _running = false;
    _timer?.cancel();
    _timer = null;
  }

  void shutdown() {
    pause();
  }

  Future<DataHygieneReport> runNow() async {
    final int cache = await _cacheCleanup.run();
    final int orphans = await _orphanCleanup.run();
    final bool expiredSession = await _expiredSessionCleanup.run();
    final int stale = await _staleNotificationCleanup.run();

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
