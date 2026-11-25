import 'dart:convert';

import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/domain/planning/habit_reminder_days.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  HabitEntity habit({
    HabitCadence cadence = HabitCadence.weekly,
    List<int>? weekdays,
    int? day,
  }) => HabitEntity(
    id: 'walk',
    title: 'Evening walk',
    createdAt: DateTime.utc(2026, 9, 1),
    updatedAt: DateTime.utc(2026, 9, 2),
    cadence: cadence,
    reminderMinutes: 18 * 60,
    reminderWeekdays: weekdays,
    reminderDayOfMonth: day,
  );

  group('stored reminder days', () {
    test('chosen weekdays and day of month survive saving and loading', () {
      final weekly = HabitEntity.fromJson(
        jsonDecode(jsonEncode(habit(weekdays: [5, 3]).toJson()))
            as Map<String, dynamic>,
      );
      expect(weekly.reminderWeekdays, [3, 5]);
      expect(weekly.reminderDayOfMonth, isNull);

      final monthly = HabitEntity.fromJson(
        jsonDecode(
              jsonEncode(
                habit(
                  cadence: HabitCadence.monthly,
                  day: HabitEntity.lastDayOfMonth,
                ).toJson(),
              ),
            )
            as Map<String, dynamic>,
      );
      expect(monthly.reminderDayOfMonth, HabitEntity.lastDayOfMonth);
      expect(monthly.reminderWeekdays, isNull);
      expect(monthly.reminderMinutes, 18 * 60);
    });

    test('a habit without chosen days writes no new fields', () {
      final json = habit().toJson();
      expect(json.containsKey('reminderWeekdays'), isFalse);
      expect(json.containsKey('reminderDayOfMonth'), isFalse);
    });

    test('habits saved before days could be chosen load unchanged', () {
      // The exact shape older builds wrote.
      final old = HabitEntity.fromJson(<String, dynamic>{
        'id': 'walk',
        'title': 'Evening walk',
        'userId': null,
        'createdAt': '2026-09-01T00:00:00.000Z',
        'updatedAt': '2026-09-02T00:00:00.000Z',
        'description': null,
        'cadence': 'weekly',
        'targetCount': 2,
        'frequencyRevision': 0,
        'frequencyStartedAt': null,
        'stepTaskIds': <String>[],
        'status': 'active',
        'active': true,
        'reminderMinutes': 1200,
      });
      expect(old.reminderWeekdays, isNull);
      expect(old.reminderDayOfMonth, isNull);
      expect(old.reminderMinutes, 1200);
      expect(old.targetCount, 2);
      expect(old.cadence, HabitCadence.weekly);
    });

    test('unreadable days fall back to Monday and the 1st', () {
      Map<String, dynamic> base() => habit().toJson();
      for (final Object? raw in <Object?>[
        'monday',
        <Object?>[],
        <Object?>[0, 8, 'x'],
        42,
      ]) {
        expect(
          HabitEntity.fromJson({
            ...base(),
            'reminderWeekdays': raw,
          }).reminderWeekdays,
          isNull,
          reason: '$raw',
        );
      }
      expect(
        HabitEntity.fromJson({
          ...base(),
          'reminderWeekdays': [7, 1, 7, 9],
        }).reminderWeekdays,
        [1, 7],
      );
      for (final Object? raw in <Object?>[0, 29, 30, 32, '15', -1]) {
        expect(
          HabitEntity.fromJson({
            ...base(),
            'reminderDayOfMonth': raw,
          }).reminderDayOfMonth,
          isNull,
          reason: '$raw',
        );
      }
      expect(
        HabitEntity.fromJson({
          ...base(),
          'reminderDayOfMonth': 28,
        }).reminderDayOfMonth,
        28,
      );
    });

    test('editing other fields keeps the chosen days; clearing removes', () {
      final chosen = habit(weekdays: [2, 4]);
      expect(chosen.copyWith(title: 'Walk').reminderWeekdays, [2, 4]);
      expect(chosen.copyWith(clearReminder: true).reminderWeekdays, [2, 4]);
      final cleared = chosen.copyWith(clearReminderDays: true);
      expect(cleared.reminderWeekdays, isNull);
      expect(cleared.reminderDayOfMonth, isNull);
      expect(
        habit(
          cadence: HabitCadence.monthly,
        ).copyWith(reminderDayOfMonth: 12).reminderDayOfMonth,
        12,
      );
    });
  });

  group('reminder day words', () {
    String describe(
      HabitCadence cadence, {
      List<int>? weekdays,
      int? day,
      required bool spanish,
    }) => HabitReminderDays.describe(
      cadence: cadence,
      weekdays: weekdays,
      dayOfMonth: day,
      spanish: spanish,
    );

    test('state the chosen days in English', () {
      expect(describe(HabitCadence.daily, spanish: false), 'every day');
      expect(describe(HabitCadence.weekly, spanish: false), 'every Monday');
      expect(
        describe(HabitCadence.weekly, weekdays: [3], spanish: false),
        'every Wednesday',
      );
      expect(
        describe(HabitCadence.weekly, weekdays: [3, 5], spanish: false),
        'every Wednesday and Friday',
      );
      expect(
        describe(HabitCadence.weekly, weekdays: [1, 3, 5], spanish: false),
        'every Monday, Wednesday and Friday',
      );
      expect(
        describe(
          HabitCadence.weekly,
          weekdays: [1, 2, 3, 4, 5, 6, 7],
          spanish: false,
        ),
        'every day',
      );
      expect(
        describe(HabitCadence.monthly, spanish: false),
        'on the 1st of each month',
      );
      expect(
        describe(HabitCadence.monthly, day: 22, spanish: false),
        'on the 22nd of each month',
      );
      expect(
        describe(HabitCadence.monthly, day: 13, spanish: false),
        'on the 13th of each month',
      );
      expect(
        describe(
          HabitCadence.monthly,
          day: HabitEntity.lastDayOfMonth,
          spanish: false,
        ),
        'on the last day of each month',
      );
    });

    test('state the chosen days in Spanish', () {
      expect(describe(HabitCadence.daily, spanish: true), 'cada día');
      expect(describe(HabitCadence.weekly, spanish: true), 'cada lunes');
      expect(
        describe(HabitCadence.weekly, weekdays: [3, 5], spanish: true),
        'cada miércoles y viernes',
      );
      expect(
        describe(HabitCadence.weekly, weekdays: [1, 6, 7], spanish: true),
        'cada lunes, sábado y domingo',
      );
      expect(
        describe(HabitCadence.monthly, spanish: true),
        'el día 1 de cada mes',
      );
      expect(
        describe(HabitCadence.monthly, day: 15, spanish: true),
        'el día 15 de cada mes',
      );
      expect(
        describe(
          HabitCadence.monthly,
          day: HabitEntity.lastDayOfMonth,
          spanish: true,
        ),
        'el último día de cada mes',
      );
    });

    test('name single days for pickers in both languages', () {
      expect(HabitReminderDays.shortWeekdayName(1, spanish: false), 'Mon');
      expect(HabitReminderDays.shortWeekdayName(7, spanish: true), 'dom');
      expect(HabitReminderDays.weekdayName(3, spanish: true), 'miércoles');
      expect(HabitReminderDays.dayOfMonthName(1, spanish: false), '1st');
      expect(HabitReminderDays.dayOfMonthName(1, spanish: true), 'Día 1');
      expect(
        HabitReminderDays.dayOfMonthName(
          HabitEntity.lastDayOfMonth,
          spanish: false,
        ),
        'Last day',
      );
      expect(
        HabitReminderDays.dayOfMonthName(
          HabitEntity.lastDayOfMonth,
          spanish: true,
        ),
        'Último día',
      );
    });
  });
}
