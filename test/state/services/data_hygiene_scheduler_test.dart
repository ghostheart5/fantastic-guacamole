import 'dart:async';

import 'package:fantastic_guacamole/state/services/data_hygiene_scheduler.dart';
import 'package:fantastic_guacamole/state/services/retention_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('shares one active cleanup run and permits a later run', () async {
    final Completer<int> cacheCleanup = Completer<int>();
    int cacheRuns = 0;
    final DataHygieneScheduler scheduler = DataHygieneScheduler.forTesting(
      runCacheCleanup: () {
        cacheRuns++;
        return cacheCleanup.future;
      },
      runOrphanCleanup: () async => 0,
      runExpiredSessionCleanup: () async => false,
      runStaleNotificationCleanup: () async => 0,
      retentionPolicy: RetentionPolicy.standard,
    );

    final Future<DataHygieneReport> first = scheduler.runNow();
    final Future<DataHygieneReport> second = scheduler.runNow();

    expect(identical(first, second), isTrue);
    expect(cacheRuns, 1);

    cacheCleanup.complete(1);
    expect((await first).totalActions, 1);

    await scheduler.runNow();
    expect(cacheRuns, 2);
  });
}
