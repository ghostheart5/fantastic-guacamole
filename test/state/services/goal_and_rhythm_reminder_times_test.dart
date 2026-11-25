import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/domain/entities/habit_occurrence_entity.dart';
import 'package:fantastic_guacamole/domain/entities/notification_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_notification_repository.dart';
import 'package:fantastic_guacamole/domain/planning/rhythm_planning_context.dart';
import 'package:fantastic_guacamole/domain/ports/notification_scheduler_port.dart';
import 'package:fantastic_guacamole/state/models/goal_progress_view.dart';
import 'package:fantastic_guacamole/state/services/notifications_service.dart';
import 'package:fantastic_guacamole/state/services/reminder_orchestrator_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final DateTime now = DateTime(2026, 11, 13, 14); // Friday afternoon.

  group('goal reminders', () {
    test('deadline reminders land at 9 AM, never at midnight', () {
      final fixture = _Fixture(now);
      final slots = fixture.service.goalReminderSlots(
        _goal(target: DateTime(2026, 11, 23)),
        progress: const GoalProgressView.empty(),
        progressKnown: true,
        now: now,
        previousNudges: {},
        nextNudges: {},
      );
      expect(
        {for (final slot in slots) slot.id: slot.at},
        {
          'goal_reminder_g_3d': DateTime(2026, 11, 20, 9),
          'goal_reminder_g': DateTime(2026, 11, 22, 9),
          'goal_reminder_g_due': DateTime(2026, 11, 23, 9),
        },
      );
      expect(slots.last.body, '"Run a 5K" is due today.');
    });

    test('past slots are skipped as the deadline approaches', () {
      final fixture = _Fixture(now);
      final slots = fixture.service.goalReminderSlots(
        _goal(target: DateTime(2026, 11, 14)),
        progress: const GoalProgressView.empty(),
        progressKnown: true,
        now: now,
        previousNudges: {},
        nextNudges: {},
      );
      expect(slots.map((slot) => slot.id), ['goal_reminder_g_due']);
    });

    test('almost-there nudge fires once, next morning', () {
      final fixture = _Fixture(now);
      final next = <String, DateTime>{};
      final slots = fixture.service.goalReminderSlots(
        _goal(target: DateTime(2026, 12, 30)),
        progress: _progress(done: 3, total: 4),
        progressKnown: true,
        now: now,
        previousNudges: {},
        nextNudges: next,
      );
      final close = slots.singleWhere((slot) => slot.id.endsWith('_close'));
      expect(close.at, DateTime(2026, 11, 14, 9));
      expect(close.body, 'One step left on "Run a 5K".');
      expect(next, {'g': DateTime(2026, 11, 14, 9)});

      // After it fired, a later sync must not schedule it again.
      final later = DateTime(2026, 11, 14, 12);
      final again = fixture.service.goalReminderSlots(
        _goal(target: DateTime(2026, 12, 30)),
        progress: _progress(done: 3, total: 4),
        progressKnown: true,
        now: later,
        previousNudges: next,
        nextNudges: {},
      );
      expect(again.where((slot) => slot.id.endsWith('_close')), isEmpty);
    });

    test('no nudge for early progress or when the deadline is tomorrow', () {
      final fixture = _Fixture(now);
      List<GoalReminderSlot> slots(GoalEntity goal, GoalProgressView p) =>
          fixture.service.goalReminderSlots(
            goal,
            progress: p,
            progressKnown: true,
            now: now,
            previousNudges: {},
            nextNudges: {},
          );
      expect(
        slots(
          _goal(),
          _progress(done: 1, total: 4),
        ).where((slot) => slot.id.endsWith('_close')),
        isEmpty,
      );
      expect(
        slots(
          _goal(target: DateTime(2026, 11, 14)),
          _progress(done: 3, total: 4),
        ).where((slot) => slot.id.endsWith('_close')),
        isEmpty,
      );
    });

    group('overdue nudge', () {
      List<GoalReminderSlot> overdue(_Fixture fixture, {required bool on}) =>
          fixture.service
              .goalReminderSlots(
                _goal(target: DateTime(2026, 11, 14)),
                progress: _progress(done: 1, total: 3),
                progressKnown: true,
                now: now,
                previousNudges: {},
                nextNudges: {},
                overdueNudges: on,
              )
              .where((slot) => slot.id.endsWith('_overdue'))
              .toList();

      test('arrives at 9 AM the day after the target date', () {
        final slot = overdue(_Fixture(now), on: true).single;
        expect(slot.id, 'goal_reminder_g_overdue');
        expect(slot.at, DateTime(2026, 11, 15, 9));
        expect(slot.title, 'Goal overdue');
        expect(
          slot.body,
          '"Run a 5K" was due yesterday and is still open. '
          '1 of 3 steps done.',
        );
      });

      test('is written in Spanish when the app is in Spanish', () {
        final slot = overdue(_Fixture(now, spanish: true), on: true).single;
        expect(slot.title, 'Meta vencida');
        expect(
          slot.body,
          '«Run a 5K» venció ayer y sigue pendiente. '
          '1 de 3 pasos hechos.',
        );
      });

      test('is left out while overdue nudges are off', () {
        expect(overdue(_Fixture(now), on: false), isEmpty);
      });

      test('is not registered once its time has passed', () {
        final fixture = _Fixture(now);
        final slots = fixture.service.goalReminderSlots(
          _goal(target: DateTime(2026, 11, 12)),
          progress: const GoalProgressView.empty(),
          progressKnown: true,
          now: now,
          previousNudges: {},
          nextNudges: {},
          overdueNudges: true,
        );
        expect(slots, isEmpty);
      });
    });

    group('goal due today after 9 AM', () {
      List<GoalReminderSlot> dueToday(
        DateTime at, {
        Map<String, DateTime> previous = const {},
        Map<String, DateTime>? next,
      }) => _Fixture(at).service
          .goalReminderSlots(
            _goal(target: DateTime(2026, 11, 13)),
            progress: const GoalProgressView.empty(),
            progressKnown: true,
            now: at,
            previousNudges: {},
            nextNudges: {},
            previousDueTimes: previous,
            nextDueTimes: next,
          )
          .where((slot) => slot.id == 'goal_reminder_g_due')
          .toList();

      test('gets one evening reminder at 6 PM', () {
        final next = <String, DateTime>{};
        final slot = dueToday(DateTime(2026, 11, 13, 14), next: next).single;
        expect(slot.at, DateTime(2026, 11, 13, 18));
        expect(slot.title, 'Goal due today');
        expect(next, {'g': DateTime(2026, 11, 13, 18)});
      });

      test('still gets it at 5:30 PM, half an hour ahead', () {
        expect(
          dueToday(DateTime(2026, 11, 13, 17, 30)).single.at,
          DateTime(2026, 11, 13, 18),
        );
      });

      test('gets none after 5:30 PM', () {
        expect(dueToday(DateTime(2026, 11, 13, 17, 31)), isEmpty);
      });

      test('gets none when the 9 AM reminder was already set up', () {
        final next = <String, DateTime>{};
        expect(
          dueToday(
            DateTime(2026, 11, 13, 10),
            previous: {'g': DateTime(2026, 11, 13, 9)},
            next: next,
          ),
          isEmpty,
        );
        expect(next, {'g': DateTime(2026, 11, 13, 9)});
      });

      test('keeps an evening reminder already set up after 5:30 PM', () {
        expect(
          dueToday(
            DateTime(2026, 11, 13, 17, 45),
            previous: {'g': DateTime(2026, 11, 13, 18)},
          ).single.at,
          DateTime(2026, 11, 13, 18),
        );
      });

      test('the morning reminder is remembered while it is planned', () {
        final next = <String, DateTime>{};
        _Fixture(now).service.goalReminderSlots(
          _goal(target: DateTime(2026, 11, 14)),
          progress: const GoalProgressView.empty(),
          progressKnown: true,
          now: now,
          previousNudges: {},
          nextNudges: {},
          nextDueTimes: next,
        );
        expect(next, {'g': DateTime(2026, 11, 14, 9)});
      });
    });

    test('sync uses linked-task progress and cancels a removed goal', () async {
      final fixture = _Fixture(now)
        ..tasks = [
          for (var i = 0; i < 4; i++)
            TaskEntity(
              id: 't$i',
              title: 'Step $i',
              goalId: 'g',
              isCompleted: i < 3,
            ),
        ];
      final goal = _goal(target: DateTime(2026, 11, 23));
      await fixture.service.syncGoalReminders([goal]);
      expect(fixture.repository.scheduled, ['goal_reminder_g']);
      expect(fixture.scheduler.scheduled, [
        'goal_reminder_g_3d',
        'goal_reminder_g_due',
        'goal_reminder_g_close',
      ]);

      await fixture.service.syncGoalReminders([]);
      expect(fixture.repository.cancelled, ['goal_reminder_g']);
      expect(fixture.scheduler.cancelled, [
        'goal_reminder_g_3d',
        'goal_reminder_g_due',
        'goal_reminder_g_close',
        'goal_reminder_g_overdue',
      ]);
    });
  });

  group('rhythm reminders', () {
    test(
      'each rhythm with a time gets its own reminder at that time',
      () async {
        final fixture = _Fixture(now);
        await fixture.service.syncHabitReminders([
          _habit('dishes', minutes: 17 * 60),
          _habit('meds', minutes: 8 * 60),
          _habit('stretch'),
        ]);
        expect(fixture.scheduler.cancelled, ['habit_reminder_daily']);
        expect(fixture.scheduler.cadences, {
          'habit_reminder_dishes': DateTime(2026, 11, 13, 17),
          'habit_reminder_meds': DateTime(2026, 11, 14, 8),
        });

        // Clearing the meds time removes only that reminder.
        fixture.scheduler.cadences.clear();
        fixture.scheduler.cancelled.clear();
        await fixture.service.syncHabitReminders([
          _habit('dishes', minutes: 17 * 60),
          _habit('meds'),
        ]);
        expect(
          fixture.scheduler.cancelled,
          containsAll(['habit_reminder_dishes', 'habit_reminder_meds']),
        );
        expect(fixture.scheduler.cadences.keys, ['habit_reminder_dishes']);
      },
    );

    test('a rhythm already done today waits for tomorrow', () {
      final habit = _habit('dishes', minutes: 17 * 60);
      final done = HabitOccurrenceEntity(
        habitId: 'dishes',
        occurrenceKey: RhythmPlanningContext.occurrenceKey(habit, now),
        operationId: 'op',
        outcome: HabitOccurrenceOutcome.completed,
        recordedAt: now,
      );
      expect(
        ReminderOrchestratorService.nextHabitReminderAt(habit, [done], now),
        DateTime(2026, 11, 14, 17),
      );
    });

    test('reminder time survives saving and loading', () {
      final habit = _habit('meds', minutes: 8 * 60 + 30);
      final restored = HabitEntity.fromJson(habit.toJson());
      expect(restored.reminderMinutes, 510);
      expect(restored.reminderHour, 8);
      expect(restored.reminderMinute, 30);
      expect(
        HabitEntity.fromJson({
          ...habit.toJson(),
          'reminderMinutes': 9999,
        }).reminderMinutes,
        isNull,
      );
      expect(restored.copyWith(clearReminder: true).reminderMinutes, isNull);
    });
  });
}

GoalEntity _goal({DateTime? target}) => GoalEntity(
  id: 'g',
  title: 'Run a 5K',
  createdAt: DateTime(2026, 11, 1),
  targetDate: target,
);

GoalProgressView _progress({required int done, required int total}) =>
    GoalProgressView.fromTasks([
      for (var i = 0; i < total; i++)
        TaskEntity(id: 't$i', title: 'Step $i', isCompleted: i < done),
    ]);

HabitEntity _habit(String id, {int? minutes}) => HabitEntity(
  id: id,
  title: id,
  createdAt: DateTime(2026, 11, 1),
  reminderMinutes: minutes,
);

class _Fixture {
  _Fixture(this.now, {this.spanish = false}) {
    // An account past the one-time move off the old shared 8 PM reminder.
    preferences.values['legacy_habit_reminder_migrated'] = 'true';
  }
  final DateTime now;
  final bool spanish;
  final preferences = _Preferences();
  final scheduler = _Scheduler();
  final repository = _Repository();
  List<TaskEntity> tasks = const [];
  late final service = ReminderOrchestratorService(
    preferences: preferences,
    notifications: NotificationsService(repository),
    scheduler: scheduler,
    accountScope: 'qa',
    now: () => now,
    loadHabitOccurrences: () async => [],
    loadGoalTasks: () async => tasks,
    isSpanish: () => spanish,
  );
}

class _Preferences implements SharedPrefsStore {
  final values = <String, String>{};
  @override
  Future<void> init() async {}
  @override
  String? load(String key) => values[key];
  @override
  Future<void> save(String key, String value) async => values[key] = value;
  @override
  Future<void> delete(String key) async => values.remove(key);
  @override
  Future<void> clear() async => values.clear();
}

class _Scheduler implements NotificationSchedulerPort {
  final scheduled = <String>[];
  final cancelled = <String>[];
  final cadences = <String, DateTime>{};
  @override
  Future<NotificationScheduleResult> schedule(
    NotificationEntity notification, {
    String? accountScope,
  }) async {
    scheduled.add(notification.id);
    return NotificationScheduleResult.scheduled;
  }

  @override
  Future<NotificationScheduleResult> scheduleCadenceAt({
    required String id,
    required String title,
    required String body,
    required HabitCadence cadence,
    required DateTime firstAt,
    String? accountScope,
  }) async {
    cadences[id] = firstAt;
    return NotificationScheduleResult.scheduled;
  }

  @override
  Future<bool> cancel(String id, {String? accountScope}) async {
    cancelled.add(id);
    return true;
  }

  @override
  Future<NotificationScheduleResult> scheduleDailyAt({
    required String id,
    required String title,
    required String body,
    required int hour,
    required int minute,
    String? accountScope,
  }) async => NotificationScheduleResult.scheduled;
  @override
  Future<List<String>> pendingIdsForAccount(String accountScope) async =>
      const <String>[];
  @override
  Future<bool> requestPermissions() async => true;
  @override
  Future<bool> cancelAll() async => true;
  @override
  void clearTappedPayload() {}
}

class _Repository implements INotificationRepository {
  final scheduled = <String>[];
  final cancelled = <String>[];
  @override
  Future<void> scheduleNotification(NotificationEntity notification) async {
    scheduled.add(notification.id);
  }

  @override
  Future<void> cancelNotification(String id) async => cancelled.add(id);
  @override
  Future<List<NotificationEntity>> getNotifications() async => [];
  @override
  Future<void> markRead(String id) async {}
  @override
  Future<void> delete(String id) async {}
}
