import 'dart:async';

import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/core/debug/runtime_diagnostics.dart';
import 'package:fantastic_guacamole/system/notifications/local_timezone.dart';
import 'package:fantastic_guacamole/system/notifications/notification_scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

void main() {
  setUpAll(tzdata.initializeTimeZones);
  setUp(() {
    Logger.errorOutputEnabled = false;
    addTearDown(() => Logger.errorOutputEnabled = true);
    tz.setLocalLocation(tz.getLocation('Etc/UTC'));
    RuntimeDiagnostics.events.value = const <RuntimeDiagnosticEvent>[];
  });
  tearDown(() => tz.setLocalLocation(tz.getLocation('Etc/UTC')));

  tz.TZDateTime nextDailyAtEight(tz.TZDateTime now) =>
      NotificationScheduler.nextDailyScheduledTime(
        now: now,
        location: tz.local,
        hour: 8,
        minute: 0,
      );

  test(
    'a zone change between two refreshes moves the next daily reminder',
    () async {
      final DateTime instant = DateTime.utc(2026, 10, 13, 14);

      await refreshLocalTimezone(readName: () async => 'America/Chicago');
      final tz.TZDateTime inChicago = nextDailyAtEight(
        tz.TZDateTime.from(instant, tz.local),
      );

      await refreshLocalTimezone(readName: () async => 'Europe/Paris');
      final tz.TZDateTime inParis = nextDailyAtEight(
        tz.TZDateTime.from(instant, tz.local),
      );

      expect(inChicago.hour, 8);
      expect(inParis.hour, 8);
      expect(inChicago.toUtc(), DateTime.utc(2026, 10, 14, 13));
      expect(inParis.toUtc(), DateTime.utc(2026, 10, 14, 6));
    },
  );

  test('a failed lookup uses the device offset instead of UTC', () async {
    await refreshLocalTimezone(
      readName: () async => throw StateError('no zone'),
      readOffset: () => const Duration(hours: 5, minutes: 30),
    );

    final tz.TZDateTime next = nextDailyAtEight(
      tz.TZDateTime.from(DateTime.utc(2026, 10, 13, 14), tz.local),
    );
    expect(tz.local.name, 'Fixed/UTC+05:30');
    expect(next.timeZoneOffset, const Duration(hours: 5, minutes: 30));
    expect(next.toUtc(), DateTime.utc(2026, 10, 14, 2, 30));
  });

  test('a failed lookup with a negative offset is built correctly', () async {
    await refreshLocalTimezone(
      readName: () async => throw StateError('no zone'),
      readOffset: () => const Duration(hours: -3, minutes: -30),
    );

    expect(tz.local.name, 'Fixed/UTC-03:30');
    expect(
      tz.TZDateTime.now(tz.local).timeZoneOffset,
      const Duration(hours: -3, minutes: -30),
    );
  });

  test('a failed lookup records exactly one coded diagnostic', () async {
    await refreshLocalTimezone(
      readName: () async => throw StateError('no zone'),
      readOffset: () => const Duration(hours: 2),
    );

    final List<RuntimeDiagnosticEvent> coded = RuntimeDiagnostics.events.value
        .where((e) => e.category == 'timezone.lookup_failed')
        .toList();
    expect(coded, hasLength(1));
    expect(coded.single.data['offsetMinutes'], '120');
  });

  test('an unknown zone name falls back like a failed lookup', () async {
    await refreshLocalTimezone(
      readName: () async => 'Not/AZone',
      readOffset: () => const Duration(hours: 1),
    );
    expect(tz.local.name, 'Fixed/UTC+01:00');
  });

  test('a cancelled caller leaves the zone untouched', () async {
    await refreshLocalTimezone(
      readName: () async => 'Europe/Paris',
      shouldApply: () => false,
    );
    expect(tz.local.name, 'Etc/UTC');
  });

  test('a lookup that never answers falls back instead of hanging', () async {
    await refreshLocalTimezone(
      readName: () => Completer<String>().future,
      readOffset: () => const Duration(hours: 4),
      lookupTimeout: const Duration(milliseconds: 20),
    );
    expect(tz.local.name, 'Fixed/UTC+04:00');
  });
}
