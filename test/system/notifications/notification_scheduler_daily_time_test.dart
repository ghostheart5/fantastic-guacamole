import 'package:fantastic_guacamole/system/notifications/notification_scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

void main() {
  late tz.Location chicago;
  setUpAll(() {
    tzdata.initializeTimeZones();
    chicago = tz.getLocation('America/Chicago');
  });
  tz.TZDateTime next(tz.TZDateTime now) =>
      NotificationScheduler.nextDailyScheduledTime(
        now: now,
        location: chicago,
        hour: 7,
        minute: 30,
      );

  test('spring DST tomorrow preserves requested 07:30 instead of 08:30', () {
    final actual = next(tz.TZDateTime(chicago, 2026, 3, 7, 9));
    expect(
      (actual.year, actual.month, actual.day, actual.hour, actual.minute),
      (2026, 3, 8, 7, 30),
    );
    expect(actual.toUtc(), DateTime.utc(2026, 3, 8, 12, 30));
    expect(actual.timeZoneOffset, const Duration(hours: -5));
  });
  test('fall DST tomorrow preserves requested 07:30 instead of 06:30', () {
    final actual = next(tz.TZDateTime(chicago, 2026, 10, 31, 9));
    expect(
      (actual.year, actual.month, actual.day, actual.hour, actual.minute),
      (2026, 11, 1, 7, 30),
    );
    expect(actual.toUtc(), DateTime.utc(2026, 11, 1, 13, 30));
    expect(actual.timeZoneOffset, const Duration(hours: -6));
  });
  test('ordinary passed deadline schedules tomorrow at original time', () {
    final actual = next(tz.TZDateTime(chicago, 2026, 10, 13, 9));
    expect(actual, tz.TZDateTime(chicago, 2026, 10, 14, 7, 30));
  });
  test('before deadline retains today at requested time', () {
    final actual = next(tz.TZDateTime(chicago, 2026, 10, 13, 7, 29, 59));
    expect(actual, tz.TZDateTime(chicago, 2026, 10, 13, 7, 30));
  });
  test('equal deadline retains the current deadline policy', () {
    final now = tz.TZDateTime(chicago, 2026, 10, 13, 7, 30);
    expect(next(now), now);
  });
  test('just after deadline advances exactly one calendar day', () {
    final actual = next(tz.TZDateTime(chicago, 2026, 10, 13, 7, 30, 0, 0, 1));
    expect(actual, tz.TZDateTime(chicago, 2026, 10, 14, 7, 30));
  });
  test('calendar rollover preserves requested time across year boundary', () {
    final actual = next(tz.TZDateTime(chicago, 2026, 12, 31, 9));
    expect(actual, tz.TZDateTime(chicago, 2027, 1, 1, 7, 30));
  });
}
