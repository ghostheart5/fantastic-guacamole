import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/state/providers/automation_schedule_projection.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  DateTime project(DateTime now, HabitCadence? cadence, DateTime? first) =>
      nextRegisteredAutomationTime(
        now: now,
        hour: 20,
        minute: 0,
        cadence: cadence,
        firstScheduledLocal: first,
      );

  test('completed daily period retains the future first date', () {
    expect(
      project(
        DateTime(2026, 10, 13, 16),
        HabitCadence.daily,
        DateTime(2026, 10, 14, 20),
      ),
      DateTime(2026, 10, 14, 20),
    );
  });
  test('weekly registration is not displayed as today daily', () {
    expect(
      project(
        DateTime(2026, 10, 13, 16),
        HabitCadence.weekly,
        DateTime(2026, 10, 19, 20),
      ),
      DateTime(2026, 10, 19, 20),
    );
  });
  test('monthly registration retains next month lower bound', () {
    expect(
      project(
        DateTime(2026, 10, 13, 16),
        HabitCadence.monthly,
        DateTime(2026, 11, 1, 20),
      ),
      DateTime(2026, 11, 1, 20),
    );
  });
  test('past first weekly date advances by calendar weekday', () {
    expect(
      project(
        DateTime(2026, 10, 20, 16),
        HabitCadence.weekly,
        DateTime(2026, 10, 12, 20),
      ),
      DateTime(2026, 10, 26, 20),
    );
  });
  test('past monthly date advances without duration arithmetic', () {
    expect(
      project(
        DateTime(2026, 12, 2, 16),
        HabitCadence.monthly,
        DateTime(2026, 11, 1, 20),
      ),
      DateTime(2027, 1, 1, 20),
    );
  });
  test('legacy daily schedules retain their ordinary next-time behavior', () {
    expect(
      project(DateTime(2026, 10, 13, 21), null, null),
      DateTime(2026, 10, 14, 20),
    );
  });
  test('missing registered weekly first date cannot invent a time', () {
    expect(
      () => project(DateTime(2026, 10, 13, 16), HabitCadence.weekly, null),
      throwsStateError,
    );
  });
}
