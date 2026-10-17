import 'dart:convert';

import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/system/notifications/notification_scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  AndroidFlutterLocalNotificationsPlugin.registerWith();
  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  final calls = <MethodCall>[];
  var permission = true;
  var pending = <Map<String, Object>>[];
  setUp(() async {
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('America/Chicago'));
    permission = true;
    pending = [];
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'pendingNotificationRequests') return pending;
          if (call.method == 'initialize' ||
              call.method == 'areNotificationsEnabled') {
            return permission;
          }
          return null;
        });
    await NotificationScheduler().init(requestPermissions: false);
    calls.clear();
  });
  test(
    'pending cadence metadata requires known cadence and a consistent local boundary',
    () async {
      String payload(
        Object? cadence,
        Object? first, {
        String owner = 'owner-a',
      }) => jsonEncode({
        'v': 1,
        'accountScope': owner,
        'notificationId': 'habit_reminder_daily',
        'dailyHour': 20,
        'dailyMinute': 0,
        'cadence': cadence,
        'firstScheduledLocal': first,
      });
      final values = [
        payload('daily', '2026-10-13T20:00:00.000'),
        payload('weekly', '2026-10-12T20:00:00.000'),
        payload('monthly', '2026-11-01T20:00:00.000'),
        payload('unknown', '2026-10-13T20:00:00.000'),
        payload('weekly', '2026-10-13T20:00:00.000'),
        payload('monthly', '2026-11-02T20:00:00.000'),
        payload('daily', '2026-10-13T20:00:00.000Z'),
        payload('daily', '2026-02-31T20:00:00.000'),
        payload('daily', '2026-10-13T19:00:00.000'),
        jsonEncode({
          'v': 1,
          'accountScope': 'owner-a',
          'notificationId': 'habit_reminder_daily',
          'dailyHour': 20,
          'dailyMinute': 0,
          'cadence': 'daily',
        }),
        jsonEncode({
          'v': 1,
          'accountScope': 'owner-a',
          'notificationId': 'habit_reminder_daily',
          'dailyHour': 20,
          'dailyMinute': 0,
          'firstScheduledLocal': '2026-10-13T20:00:00.000',
        }),
        NotificationScheduler.accountPayload(
          'owner-a',
          'daily_planning_reminder',
          dailyHour: 20,
          dailyMinute: 0,
        ),
        payload('daily', '2026-10-13T20:00:00.000', owner: 'owner-b'),
      ];
      pending = [
        for (var i = 0; i < values.length; i++)
          {
            'id': i,
            'title': 'Reminder',
            'body': 'Rhythm',
            'payload': values[i],
          },
      ];
      final rows = await NotificationScheduler().pendingForAccount('owner-a');
      expect(rows, hasLength(12));
      expect(rows.take(3).map((row) => row.cadence), HabitCadence.values);
      expect(
        rows.take(3).every((row) => row.firstScheduledLocal != null),
        isTrue,
      );
      expect(
        rows
            .skip(3)
            .every(
              (row) => row.cadence == null && row.firstScheduledLocal == null,
            ),
        isTrue,
      );
      expect(rows.every((row) => row.hour == 20 && row.minute == 0), isTrue);
      expect(
        rows.take(3).every((row) => !row.cadenceMetadataMalformed),
        isTrue,
      );
      expect(
        rows.skip(3).take(8).every((row) => row.cadenceMetadataMalformed),
        isTrue,
      );
      expect(rows.last.cadenceMetadataMalformed, isFalse);
      expect(calls.any((call) => call.method == 'zonedSchedule'), isFalse);
    },
  );
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
  test(
    'unsupported platform rejects cadence without a daily fallback',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(
        await NotificationScheduler().scheduleCadenceAt(
          id: 'habit',
          title: 'Habit',
          body: 'Rhythm',
          cadence: HabitCadence.daily,
          firstAt: DateTime(2099),
          accountScope: 'owner-a',
        ),
        isFalse,
      );
      expect(calls, isEmpty);
    },
  );
  for (final cadence in HabitCadence.values) {
    test(
      '$cadence sends explicit first date, local zone and native calendar match',
      () async {
        final firstAt = DateTime(2099, 6, 1, 20);
        expect(
          await NotificationScheduler().scheduleCadenceAt(
            id: 'habit_reminder_daily',
            title: 'Habit Reminder',
            body: 'First rhythm',
            cadence: cadence,
            firstAt: firstAt,
            accountScope: 'owner-a',
          ),
          isTrue,
        );
        final args = calls.single.arguments as Map;
        expect(calls.single.method, 'zonedSchedule');
        expect(args['timeZoneName'], 'America/Chicago');
        expect(args['scheduledDateTime'], startsWith('2099-06-01T20:00:00'));
        final component = switch (cadence) {
          HabitCadence.daily => DateTimeComponents.time,
          HabitCadence.weekly => DateTimeComponents.dayOfWeekAndTime,
          HabitCadence.monthly => DateTimeComponents.dayOfMonthAndTime,
        };
        expect(args['matchDateTimeComponents'], component.index);
        final metadata = jsonDecode(args['payload'] as String) as Map;
        expect(metadata['accountScope'], 'owner-a');
        expect(metadata['notificationId'], 'habit_reminder_daily');
        expect(metadata['cadence'], cadence.name);
        expect(metadata['firstScheduledLocal'], '2099-06-01T20:00:00.000');
        expect(metadata['dailyHour'], 20);
        expect(metadata['dailyMinute'], 0);
      },
    );
  }
  test(
    'cadence replacement keeps ID stable within owner and separates other owner',
    () async {
      final scheduler = NotificationScheduler();
      Future<void> schedule(HabitCadence cadence, String scope) async {
        await scheduler.scheduleCadenceAt(
          id: 'habit_reminder_daily',
          title: 'Habit Reminder',
          body: 'Rhythm',
          cadence: cadence,
          firstAt: DateTime(2099, 6, 1, 20),
          accountScope: scope,
        );
      }

      await schedule(HabitCadence.daily, 'owner-a');
      await schedule(HabitCadence.monthly, 'owner-a');
      await schedule(HabitCadence.weekly, 'owner-b');
      final ids = calls.map((call) => (call.arguments as Map)['id']).toList();
      expect(ids[1], ids[0]);
      expect(ids[2], isNot(ids[0]));
    },
  );
  test(
    'permission denied and past first date never reach native registration',
    () async {
      final scheduler = NotificationScheduler();
      expect(
        await scheduler.scheduleCadenceAt(
          id: 'habit',
          title: 'Habit',
          body: 'Rhythm',
          cadence: HabitCadence.daily,
          firstAt: DateTime(2000),
          accountScope: 'owner-a',
        ),
        isFalse,
      );
      expect(calls, isEmpty);
      permission = false;
      await scheduler.init(requestPermissions: false);
      calls.clear();
      expect(
        await scheduler.scheduleCadenceAt(
          id: 'habit',
          title: 'Habit',
          body: 'Rhythm',
          cadence: HabitCadence.monthly,
          firstAt: DateTime(2099),
          accountScope: 'owner-a',
        ),
        isFalse,
      );
      expect(calls, isEmpty);
    },
  );
}
