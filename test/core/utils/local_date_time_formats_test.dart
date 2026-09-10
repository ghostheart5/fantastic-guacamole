import 'package:fantastic_guacamole/core/utils/date_time_formats.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('persisted UTC note uses the same local clock as Timeline', () {
    final DateTime local = DateTime(2026, 9, 10, 15, 57);
    for (final DateTime value in [local, local.toUtc()]) {
      expect(
        DateTimeFormats.relativeLocalDateTime(value, now: local),
        'Today · 3:57 PM',
      );
      expect(DateTimeFormats.timelineTime(value), '3:57 PM');
    }
  });

  test(
    'UTC storage cannot move a late local note into another calendar day',
    () {
      final DateTime local = DateTime(2026, 9, 10, 23, 57);
      expect(DateTimeFormats.localMonthDay(local.toUtc()), 'Sep 10');
      expect(
        DateTimeFormats.relativeLocalDateTime(
          local.toUtc(),
          now: DateTime(2026, 9, 11, 0, 2).toUtc(),
        ),
        'Yesterday · 11:57 PM',
      );
    },
  );

  for (final List<int> date in [
    <int>[2026, 3, 8],
    <int>[2026, 11, 1],
  ]) {
    test('relative day survives DST boundary $date', () {
      final DateTime today = DateTime(date[0], date[1], date[2], 12);
      final DateTime tomorrow = DateTime(date[0], date[1], date[2] + 1, 12);
      expect(
        DateTimeFormats.relativeLocalDateTime(tomorrow.toUtc(), now: today),
        'Tomorrow · 12:00 PM',
      );
      expect(
        DateTimeFormats.relativeLocalDateTime(today.toUtc(), now: tomorrow),
        'Yesterday · 12:00 PM',
      );
    });
  }

  test('relative days handle year boundaries and distant dates', () {
    final DateTime now = DateTime(2026, 12, 31, 23, 59);
    expect(
      DateTimeFormats.relativeLocalDateTime(
        DateTime(2027, 1, 1).toUtc(),
        now: now,
      ),
      'Tomorrow · 12:00 AM',
    );
    expect(
      DateTimeFormats.relativeLocalDateTime(
        DateTime(2027, 1, 3, 12).toUtc(),
        now: now,
      ),
      'Jan 3 · 12:00 PM',
    );
  });
}
