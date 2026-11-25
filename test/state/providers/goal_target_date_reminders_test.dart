import 'dart:convert';

import 'package:fantastic_guacamole/core/storage/account_storage_namespace.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_goal_repository.dart';
import 'package:fantastic_guacamole/state/controllers/profile_controller.dart';
import 'package:fantastic_guacamole/state/providers/logs_provider.dart';
import 'package:fantastic_guacamole/state/providers/timeline_provider.dart';
import 'package:fantastic_guacamole/state/state/logs_state.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/goals_provider.dart';
import 'package:fantastic_guacamole/state/providers/repository_providers.dart';
import 'package:fantastic_guacamole/state/providers/service_providers.dart';
import 'package:fantastic_guacamole/state/providers/settings_ui_provider.dart';
import 'package:fantastic_guacamole/state/services/notifications_service.dart';
import 'package:fantastic_guacamole/state/services/reminder_orchestrator_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'task_reminder_test_support.dart';

const String _base = 'goal_reminder_g';

void main() {
  test('changing a goal date moves its reminders and clearing it cancels '
      'them', () async {
    final fixture = _Fixture();
    final GoalsNotifier notifier = fixture.container.read(
      goalsProvider.notifier,
    );

    // Set: a goal with no date gets all five slots once it has one.
    await notifier.update(
      fixture.goal.copyWith(targetDate: DateTime(2026, 11, 20)),
    );
    expect(fixture.scheduler.pending, <String>{
      '${_base}_3d',
      '${_base}_due',
      '${_base}_overdue',
    });
    expect(fixture.scheduler.times['${_base}_3d'], DateTime(2026, 11, 17, 9));

    // Change: the same slots move with the date.
    fixture.scheduler.clearLog();
    await notifier.update(
      fixture.goal.copyWith(targetDate: DateTime(2026, 12, 10)),
    );
    expect(fixture.scheduler.times['${_base}_3d'], DateTime(2026, 12, 7, 9));
    expect(fixture.scheduler.times['${_base}_due'], DateTime(2026, 12, 10, 9));
    expect(
      fixture.scheduler.times['${_base}_overdue'],
      DateTime(2026, 12, 11, 9),
    );

    // Today, after the morning hour: the evening fallback is remembered.
    await notifier.update(
      fixture.goal.copyWith(targetDate: DateTime(2026, 11, 2)),
    );
    expect(fixture.scheduler.times['${_base}_due'], DateTime(2026, 11, 2, 18));
    expect(jsonDecode(fixture.preferences.values['goal_due_today_times']!), {
      'g': isNotNull,
    });
    expect(fixture.scheduler.pending, contains('${_base}_due'));

    // Clear: every slot is cancelled and the remembered time is dropped.
    fixture.scheduler.clearLog();
    await notifier.update(fixture.goal.copyWith(clearTargetDate: true));
    expect(fixture.scheduler.pending, isEmpty);
    expect(
      fixture.scheduler.cancelled,
      containsAll(<String>['${_base}_3d', '${_base}_due', '${_base}_overdue']),
    );
    expect(
      jsonDecode(fixture.preferences.values['goal_due_today_times'] ?? '{}'),
      isEmpty,
    );
  });
}

class _Fixture {
  _Fixture() {
    container = ProviderContainer(
      overrides: [
        accountStorageScopeProvider.overrideWithValue(
          AccountStorageScope.authenticated('goal-date-user'),
        ),
        accountLegacyOwnershipProvider.overrideWithValue(
          LegacyScopeOwnership.provenNotOwned,
        ),
        taskStoreProvider.overrideWithValue(store),
        domainGoalRepositoryProvider.overrideWithValue(
          _Goals(<GoalEntity>[goal]),
        ),
        logsProvider.overrideWith(_Logs.new),
        timelineProvider.overrideWith(_Timeline.new),
        profileProvider.overrideWith(_Profile.new),
        notificationSchedulerProvider.overrideWithValue(scheduler),
        localTimezoneRefresherProvider.overrideWithValue(() async {}),
        reminderOrchestratorServiceProvider.overrideWith(
          (ref) => ReminderOrchestratorService(
            preferences: preferences,
            notifications: NotificationsService(NoNotificationList()),
            scheduler: scheduler,
            accountScope: testReminderScope,
            loadTasks: () => store.getAllTasks(),
            loadGoalTasks: () => store.getAllTasks(),
            now: () => now,
            isSpanish: () => false,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    preferences.values['task_overdue_nudges_enabled'] = 'true';
  }

  final DateTime now = DateTime(2026, 11, 2, 15);
  final MemoryTaskStore store = MemoryTaskStore();
  final RecordingTaskScheduler scheduler = RecordingTaskScheduler();
  final MemoryReminderPrefs preferences = MemoryReminderPrefs();
  late final ProviderContainer container;
  final GoalEntity goal = GoalEntity(
    id: 'g',
    title: 'Run a 5K',
    createdAt: DateTime.utc(2026, 10, 1),
  );
}

class _Goals implements IGoalRepository {
  _Goals(this._goals);

  final List<GoalEntity> _goals;

  @override
  List<GoalEntity> getGoals() => List<GoalEntity>.of(_goals);

  @override
  Future<void> saveGoal(GoalEntity goal) async {
    _goals
      ..removeWhere((GoalEntity g) => g.id == goal.id)
      ..add(goal);
  }

  @override
  Future<void> saveGoals(List<GoalEntity> goals) async {}

  @override
  Future<void> deleteGoal(String id) async {}
}

final class _Logs extends LogsController {
  @override
  LogsState build() => LogsState.initial();

  @override
  Future<void> add({
    required String source,
    required String message,
    String? id,
    DateTime? timestamp,
    bool syncTimeline = true,
    bool refreshPlanner = true,
    bool updateSignals = false,
    bool Function()? shouldContinue,
  }) async {}
}

final class _Timeline extends TimelineNotifier {
  @override
  List<TimelineEventEntity> build() => const <TimelineEventEntity>[];

  @override
  Future<void> record(
    TimelineEventEntity event, {
    bool refreshPlanner = true,
    bool awardProgression = false,
    bool Function()? shouldContinue,
  }) async {}
}

final class _Profile extends ProfileController {
  @override
  ProfileState build() => ProfileState();

  @override
  Future<void> awardXP(
    int amount, {
    required String source,
    bool Function()? shouldContinue,
  }) async {}
}
