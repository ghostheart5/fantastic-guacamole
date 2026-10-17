import 'dart:async';

import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/repositories/decision_outcome_repository.dart';
import 'package:fantastic_guacamole/data/repositories/habit_occurrence_repository.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/domain/entities/habit_occurrence_entity.dart';
import 'package:fantastic_guacamole/domain/entities/notification_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_notification_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_habit_repository.dart';
import 'package:fantastic_guacamole/domain/planning/rhythm_planning_context.dart';
import 'package:fantastic_guacamole/domain/ports/notification_scheduler_port.dart';
import 'package:fantastic_guacamole/state/services/notifications_service.dart';
import 'package:fantastic_guacamole/state/services/reminder_orchestrator_service.dart';
import 'package:fantastic_guacamole/state/services/habit_occurrence_coordinator.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/decision_outcome_provider.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/habit_occurrence_provider.dart';
import 'package:fantastic_guacamole/state/providers/habits_provider.dart';
import 'package:fantastic_guacamole/state/providers/service_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'account change during outcome read leaves old alarm cancelled',
    () async {
      final fixture = _Fixture(DateTime(2026, 10, 12, 10));
      final entered = Completer<void>();
      final release = Completer<void>();
      var current = true;
      final service = ReminderOrchestratorService(
        preferences: fixture.preferences,
        notifications: NotificationsService(fixture.notifications),
        scheduler: fixture.scheduler,
        accountScope: 'qa',
        now: () => fixture.now,
        loadHabitOccurrences: () async {
          entered.complete();
          await release.future;
          return [];
        },
      );
      final pending = service.syncHabitReminders([
        fixture.habit(HabitCadence.weekly),
      ], shouldContinue: () => current);
      await entered.future;
      current = false;
      release.complete();
      await pending;
      expect(fixture.scheduler.events, [
        'cancel:qa:habit_reminder_daily',
        'cancel:qa:habit_reminder_daily',
      ]);
      expect(fixture.scheduler.cadences, isEmpty);
    },
  );
  for (final action in ['complete', 'skip', 'correct', 'recordAt']) {
    test(
      'notifier $action saves terminal outcome then resyncs reminder',
      () async {
        final now = DateTime(2026, 10, 12, 10);
        final scope = AccountStorageScope.authenticated('cadence-notifier');
        final fixture = _Fixture(now);
        final habit = fixture.habit(HabitCadence.weekly);
        final repository = _Habits([habit]);
        final occurrences = HabitOccurrenceRepository(
          fixture.preferences,
          scope,
        );
        final coordinator = HabitOccurrenceCoordinator(
          scope: scope,
          habitRepository: repository,
          occurrenceRepository: occurrences,
          outcomeRepository: DecisionOutcomeRepository(
            fixture.preferences,
            scope,
          ),
          learningPaused: () async => true,
          clock: () => now,
        );
        if (action == 'correct') await coordinator.complete(habit.id);
        final service = ReminderOrchestratorService(
          preferences: fixture.preferences,
          notifications: NotificationsService(_Repository()),
          scheduler: fixture.scheduler,
          accountScope: 'qa',
          now: () => now,
          loadHabitOccurrences: occurrences.load,
        );
        final container = ProviderContainer(
          overrides: [
            accountStorageScopeProvider.overrideWithValue(scope),
            domainHabitRepositoryProvider.overrideWithValue(repository),
            habitOccurrenceCoordinatorProvider.overrideWithValue(coordinator),
            decisionOutcomeRepositoryProvider.overrideWithValue(null),
            reminderOrchestratorServiceProvider.overrideWithValue(service),
          ],
        );
        addTearDown(container.dispose);
        await container.read(habitsProvider.future);
        final notifier = container.read(habitsProvider.notifier);
        switch (action) {
          case 'complete':
            await notifier.completeHabit(habit.id);
          case 'skip':
            await notifier.skipHabit(habit.id);
          case 'correct':
            await notifier.correctHabit(
              habit.id,
              HabitOccurrenceOutcome.skipped,
            );
          case 'recordAt':
            await notifier.recordHabitAt(habit.id, now, completed: true);
        }
        expect(await occurrences.load(), hasLength(1));
        expect(
          fixture.scheduler.cadences.last.firstAt,
          DateTime(2026, 10, 19, 20),
        );
        expect(fixture.scheduler.cadences, hasLength(2));
        expect(repository.values.single.active, isTrue);
      },
    );
  }
  for (final cadence in HabitCadence.values) {
    final now = cadence == HabitCadence.monthly
        ? DateTime(2026, 11, 1, 10)
        : DateTime(2026, 10, 12, 10); // Monday, before reminder time.
    final next = switch (cadence) {
      HabitCadence.daily => DateTime(2026, 10, 13, 20),
      HabitCadence.weekly => DateTime(2026, 10, 19, 20),
      HabitCadence.monthly => DateTime(2026, 12, 1, 20),
    };
    test(
      '$cadence follows its calendar boundary, not daily fallback',
      () async {
        final fixture = _Fixture(now);
        final habit = fixture.habit(cadence);
        await fixture.service.syncHabitReminders([habit]);
        expect(fixture.scheduler.events, [
          'cancel:qa:habit_reminder_daily',
          'cadence:qa:habit_reminder_daily',
        ]);
        final schedule = fixture.scheduler.cadences.single;
        expect(schedule.cadence, cadence);
        expect(schedule.firstAt, DateTime(now.year, now.month, now.day, 20));
        expect(schedule.body, contains(habit.title));
        expect(fixture.scheduler.daily, isEmpty);
      },
    );
    for (final outcome in HabitOccurrenceOutcome.values) {
      test(
        '$cadence $outcome current period defers first active habit',
        () async {
          final fixture = _Fixture(now);
          final habit = fixture.habit(cadence);
          fixture.outcomes.add(fixture.outcome(habit, now, outcome));
          await fixture.service.syncHabitReminders([
            habit,
            fixture.habit(HabitCadence.daily, id: 'second'),
          ]);
          expect(fixture.scheduler.cadences.single.firstAt, next);
          expect(fixture.scheduler.cadences.single.body, contains(habit.title));
          expect(fixture.scheduler.cadences.single.cadence, cadence);
        },
      );
    }
    test('$cadence revision excludes historical definition outcomes', () async {
      final fixture = _Fixture(now);
      final original = fixture.habit(cadence);
      fixture.outcomes.add(
        fixture.outcome(original, now, HabitOccurrenceOutcome.completed),
      );
      final revised = original.copyWith(
        frequencyRevision: 1,
        targetCount: 2,
        frequencyStartedAt: now,
      );
      await fixture.service.syncHabitReminders([revised]);
      expect(
        fixture.scheduler.cadences.single.firstAt,
        DateTime(now.year, now.month, now.day, 20),
      );
      fixture.outcomes.add(
        fixture.outcome(revised, now, HabitOccurrenceOutcome.skipped),
      );
      await fixture.service.syncHabitReminders([revised]);
      expect(fixture.scheduler.cadences.last.firstAt, next);
    });
  }

  test('weekly midweek and monthly midmonth schedule next boundary', () async {
    final fixture = _Fixture(DateTime(2026, 10, 13, 10));
    await fixture.service.syncHabitReminders([
      fixture.habit(HabitCadence.weekly),
    ]);
    expect(
      fixture.scheduler.cadences.single.firstAt,
      DateTime(2026, 10, 19, 20),
    );
    await fixture.service.syncHabitReminders([
      fixture.habit(HabitCadence.monthly),
    ]);
    expect(fixture.scheduler.cadences.last.firstAt, DateTime(2026, 11, 1, 20));
  });
  test('daily after 20 uses next calendar day across year boundary', () async {
    final fixture = _Fixture(DateTime(2026, 12, 31, 21));
    await fixture.service.syncHabitReminders([
      fixture.habit(HabitCadence.daily),
    ]);
    expect(fixture.scheduler.cadences.single.firstAt, DateTime(2027, 1, 1, 20));
  });
  test(
    'disabled or entirely paused habits cancel without registering',
    () async {
      final fixture = _Fixture(DateTime(2026, 10, 12, 10));
      await fixture.service.syncHabitReminders([
        fixture.habit(HabitCadence.weekly).copyWith(status: HabitStatus.paused),
      ]);
      await fixture.preferences.save('habit_reminders_enabled', 'false');
      await fixture.service.syncHabitReminders([
        fixture.habit(HabitCadence.monthly),
      ]);
      expect(fixture.scheduler.cadences, isEmpty);
      expect(fixture.notifications.cancelled, [
        'habit_reminder_daily',
        'habit_reminder_daily',
      ]);
    },
  );
  test(
    'unreadable outcomes cancel old alarm and never fallback to today',
    () async {
      final fixture = _Fixture(DateTime(2026, 10, 12, 10))..loaderFails = true;
      await expectLater(
        fixture.service.syncHabitReminders([fixture.habit(HabitCadence.daily)]),
        throwsStateError,
      );
      expect(fixture.scheduler.events, ['cancel:qa:habit_reminder_daily']);
      expect(fixture.scheduler.cadences, isEmpty);
      expect(fixture.scheduler.daily, isEmpty);
    },
  );
  test('failed cancellation does not register a conflicting cadence', () async {
    final fixture = _Fixture(DateTime(2026, 10, 12, 10));
    fixture.scheduler.cancelSucceeds = false;
    await expectLater(
      fixture.service.syncHabitReminders([fixture.habit(HabitCadence.weekly)]),
      throwsStateError,
    );
    expect(fixture.scheduler.cadences, isEmpty);
  });
  test(
    'restore reuses terminal-aware cadence and leaves planning policy alone',
    () async {
      final fixture = _Fixture(DateTime(2026, 11, 1, 10));
      final habit = fixture.habit(HabitCadence.monthly);
      fixture.outcomes.add(
        fixture.outcome(habit, fixture.now, HabitOccurrenceOutcome.skipped),
      );
      expect(
        await fixture.service.reconcileAfterRestore(
          goals: [],
          habits: [habit],
          permissionGranted: true,
          shouldContinue: () => true,
        ),
        isTrue,
      );
      expect(
        fixture.scheduler.cadences.single.firstAt,
        DateTime(2026, 12, 1, 20),
      );
      expect(fixture.scheduler.daily, ['daily_planning_reminder']);
      expect(
        fixture.scheduler.events.indexOf('cancel:qa:habit_reminder_daily'),
        lessThan(
          fixture.scheduler.events.indexOf('cadence:qa:habit_reminder_daily'),
        ),
      );
    },
  );
  test(
    'restore without permission cancels but never registers or prompts',
    () async {
      final fixture = _Fixture(DateTime(2026, 10, 12, 10));
      expect(
        await fixture.service.reconcileAfterRestore(
          goals: [],
          habits: [fixture.habit(HabitCadence.weekly)],
          permissionGranted: false,
          shouldContinue: () => true,
        ),
        isFalse,
      );
      expect(fixture.scheduler.cadences, isEmpty);
      expect(fixture.scheduler.daily, isEmpty);
    },
  );
}

class _Fixture {
  _Fixture(this.now);
  final DateTime now;
  final preferences = _Preferences();
  final scheduler = _Scheduler();
  final outcomes = <HabitOccurrenceEntity>[];
  final notifications = _Repository();
  bool loaderFails = false;
  late final service = ReminderOrchestratorService(
    preferences: preferences,
    notifications: NotificationsService(notifications),
    scheduler: scheduler,
    accountScope: 'qa',
    now: () => now,
    loadHabitOccurrences: () async {
      if (loaderFails) throw StateError('Outcome storage unavailable');
      return outcomes;
    },
  );
  HabitEntity habit(HabitCadence cadence, {String id = 'first'}) => HabitEntity(
    id: id,
    title: '$id rhythm',
    createdAt: now,
    cadence: cadence,
  );
  HabitOccurrenceEntity outcome(
    HabitEntity habit,
    DateTime period,
    HabitOccurrenceOutcome outcome,
  ) => HabitOccurrenceEntity(
    habitId: habit.id,
    occurrenceKey: RhythmPlanningContext.occurrenceKey(habit, period),
    operationId: 'op-${habit.frequencyRevision}',
    outcome: outcome,
    recordedAt: now,
  );
}

class _Preferences implements SharedPrefsStore {
  final values = <String, String>{};
  @override
  Future<void> init() async {}
  @override
  String? load(String key) => values[key];
  @override
  Future<void> save(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }

  @override
  Future<void> clear() async {
    values.clear();
  }
}

class _CadenceSchedule {
  _CadenceSchedule(this.cadence, this.firstAt, this.body);
  final HabitCadence cadence;
  final DateTime firstAt;
  final String body;
}

class _Scheduler implements NotificationSchedulerPort {
  final events = <String>[];
  final cadences = <_CadenceSchedule>[];
  final daily = <String>[];
  bool cancelSucceeds = true;
  @override
  Future<bool> scheduleCadenceAt({
    required String id,
    required String title,
    required String body,
    required HabitCadence cadence,
    required DateTime firstAt,
    String? accountScope,
  }) async {
    events.add('cadence:$accountScope:$id');
    cadences.add(_CadenceSchedule(cadence, firstAt, body));
    return true;
  }

  @override
  Future<bool> cancel(String id, {String? accountScope}) async {
    events.add('cancel:$accountScope:$id');
    return cancelSucceeds;
  }

  @override
  Future<bool> scheduleDailyAt({
    required String id,
    required String title,
    required String body,
    required int hour,
    required int minute,
    String? accountScope,
  }) async {
    daily.add(id);
    return true;
  }

  @override
  Future<bool> requestPermissions() async =>
      throw StateError('Must not request permission during sync');
  @override
  Future<bool> schedule(
    NotificationEntity notification, {
    String? accountScope,
  }) async => true;
  @override
  Future<bool> cancelAll() async => true;
  @override
  void clearTappedPayload() {}
}

class _Repository implements INotificationRepository {
  final cancelled = <String>[];
  @override
  Future<void> cancelNotification(String id) async {
    cancelled.add(id);
  }

  @override
  Future<List<NotificationEntity>> getNotifications() async => [];
  @override
  Future<void> scheduleNotification(NotificationEntity notification) async {}
  @override
  Future<void> markRead(String id) async {}
  @override
  Future<void> delete(String id) async {}
}

class _Habits implements IHabitRepository {
  _Habits(this.values);
  List<HabitEntity> values;
  @override
  Future<List<HabitEntity>> getHabits() async => values;
  @override
  Future<void> saveHabits(List<HabitEntity> habits) async {
    values = habits;
  }
}
