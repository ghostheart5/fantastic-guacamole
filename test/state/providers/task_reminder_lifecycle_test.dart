import 'package:fantastic_guacamole/core/storage/account_storage_namespace.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/repositories/task_occurrence_repository.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/domain/entities/progression_entity.dart';
import 'package:fantastic_guacamole/domain/entities/recurrence_rule.dart';
import 'package:fantastic_guacamole/domain/entities/si_state_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task_occurrence_entity.dart';
import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_progression_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_si_repository.dart';
import 'package:fantastic_guacamole/engine/learning/learning_state.dart';
import 'package:fantastic_guacamole/engine/si/models/si_state.dart';
import 'package:fantastic_guacamole/state/controllers/learning_controller.dart';
import 'package:fantastic_guacamole/state/controllers/profile_controller.dart';
import 'package:fantastic_guacamole/state/controllers/si_state_controller.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/logs_provider.dart';
import 'package:fantastic_guacamole/state/providers/repository_providers.dart';
import 'package:fantastic_guacamole/state/providers/service_providers.dart';
import 'package:fantastic_guacamole/state/providers/settings_ui_provider.dart';
import 'package:fantastic_guacamole/state/providers/storage_providers.dart';
import 'package:fantastic_guacamole/state/providers/task_occurrence_provider.dart';
import 'package:fantastic_guacamole/state/providers/task_provider.dart';
import 'package:fantastic_guacamole/state/providers/task_reminder_sync_provider.dart';
import 'package:fantastic_guacamole/state/providers/timeline_provider.dart';
import 'package:fantastic_guacamole/state/services/notifications_service.dart';
import 'package:fantastic_guacamole/state/services/reminder_orchestrator_service.dart';
import 'package:fantastic_guacamole/state/services/task_occurrence_coordinator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'task_reminder_test_support.dart';

/// Task reminders through the real task actions and occurrence coordinator:
/// only storage, the OS scheduler and unrelated side effects are faked.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test(
    'completing a task through the task actions cancels its reminder',
    () async {
      final fixture = await _Fixture.withTask(fixture: _Fixture());

      await fixture.actions.completeTask('a', notify: false);
      await fixture.idle();

      expect(fixture.store.tasks['a']!.isCompleted, isTrue);
      expect(fixture.scheduler.cancelled, ['task_reminder_start_a']);
      expect(fixture.scheduler.pending, isEmpty);
    },
  );

  test(
    'skipping a task through the task actions cancels its reminder',
    () async {
      final fixture = await _Fixture.withTask(fixture: _Fixture());

      await fixture.actions.skipTask('a', notify: false);
      await fixture.idle();

      expect(fixture.store.tasks['a']!.isSkipped, isTrue);
      expect(fixture.scheduler.cancelled, ['task_reminder_start_a']);
      expect(fixture.scheduler.pending, isEmpty);
    },
  );

  test(
    'removing a task through the task actions cancels its reminder',
    () async {
      final fixture = await _Fixture.withTask(fixture: _Fixture());

      await fixture.actions.deleteTask('a');
      await fixture.idle();

      expect(fixture.store.tasks['a']!.isCanceled, isTrue);
      expect(fixture.scheduler.cancelled, ['task_reminder_start_a']);
    },
  );

  test(
    'completing a repeating task moves the reminder to its next one',
    () async {
      final fixture = await _Fixture.withTask(
        fixture: _Fixture(),
        rule: RecurrenceRule.daily,
      );

      await fixture.actions.completeTask('a', notify: false);
      await fixture.idle();

      final successor = fixture.store.tasks.values.singleWhere(
        (task) => task.id != 'a',
      );
      expect(successor.isCompleted, isFalse);
      expect(fixture.scheduler.cancelled, contains('task_reminder_start_a'));
      expect(fixture.scheduler.pending, {
        'task_reminder_start_${successor.id}',
      });
      expect(
        fixture.scheduler.times['task_reminder_start_${successor.id}'],
        successor.scheduledFor!.toUtc(),
      );
    },
  );
}

class _Fixture {
  _Fixture() {
    container = ProviderContainer(
      overrides: [
        accountStorageScopeProvider.overrideWithValue(
          AccountStorageScope.authenticated('task-lifecycle-user'),
        ),
        accountLegacyOwnershipProvider.overrideWithValue(
          LegacyScopeOwnership.provenNotOwned,
        ),
        secureStoreProvider.overrideWithValue(
          SecureStore(backend: InMemorySecureStoreBackend()),
        ),
        taskStoreProvider.overrideWithValue(store),
        // The production coordinator, writing through the real task
        // repository provider; only its ledger and clock are test doubles.
        taskOccurrenceCoordinatorProvider.overrideWith((ref) {
          final coordinator = TaskOccurrenceCoordinator(
            scope: ref.watch(accountStorageScopeProvider),
            taskRepository: ref.read(domainTaskRepositoryProvider),
            occurrenceRepository: _MemoryOccurrences(),
            clock: () => now,
          );
          ref.onDispose(coordinator.dispose);
          return coordinator;
        }),
        domainProgressionRepositoryProvider.overrideWithValue(_Progression()),
        domainSiRepositoryProvider.overrideWithValue(_Si()),
        tasksProvider.overrideWith((Ref ref) async => const <Task>[]),
        learningProvider.overrideWith(_Learning.new),
        profileProvider.overrideWith(_Profile.new),
        siStateProvider.overrideWith(_SiState.new),
        logsActionsProvider.overrideWith(_QuietLogs.new),
        timelineActionsProvider.overrideWith(_QuietTimeline.new),
        notificationSchedulerProvider.overrideWithValue(scheduler),
        localTimezoneRefresherProvider.overrideWithValue(() async {}),
        reminderOrchestratorServiceProvider.overrideWith(
          (ref) => ReminderOrchestratorService(
            preferences: MemoryReminderPrefs(),
            notifications: NotificationsService(NoNotificationList()),
            scheduler: scheduler,
            accountScope: testReminderScope,
            loadTasks: () => store.getAllTasks(),
            now: () => now,
            isSpanish: () => false,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
  }

  /// A task starting two hours after the clock, with its reminder set.
  static Future<_Fixture> withTask({
    required _Fixture fixture,
    RecurrenceRule rule = RecurrenceRule.none,
  }) async {
    await fixture.container
        .read(domainTaskRepositoryProvider)
        .saveTask(
          TaskEntity(
            id: 'a',
            title: 'Task a',
            createdAt: fixture.now.subtract(const Duration(days: 1)),
            scheduledFor: fixture.now.add(const Duration(hours: 2)),
            recurrenceRule: rule,
          ),
        );
    await fixture.idle();
    expect(fixture.scheduler.pending, {'task_reminder_start_a'});
    fixture.scheduler.clearLog();
    return fixture;
  }

  final DateTime now = DateTime.utc(2026, 11, 2, 15);
  final store = MemoryTaskStore();
  final scheduler = RecordingTaskScheduler();
  late final ProviderContainer container;

  TaskActions get actions => container.read(taskActionsProvider);

  Future<void> idle() => container.read(taskReminderSyncProvider).idle;
}

class _MemoryOccurrences extends TaskOccurrenceRepository {
  _MemoryOccurrences() : super.unavailable();
  final Map<String, TaskOccurrence> records = {};
  @override
  Future<TaskOccurrence?> getOccurrence(
    String taskId,
    String occurrenceKey,
  ) async => records['$taskId::$occurrenceKey'];
  @override
  Future<void> save(TaskOccurrence value) async {
    records[value.id] = value;
  }

  @override
  Future<List<TaskOccurrence>> listOccurrences() async =>
      records.values.toList();
  @override
  Future<List<TaskOccurrence>> listOccurrencesForTask(String taskId) async =>
      records.values.where((record) => record.taskId == taskId).toList();
}

class _Progression implements IProgressionRepository {
  ProgressionEntity? progression = const ProgressionEntity(xp: 0);
  @override
  Future<ProgressionEntity?> getProgression() async => progression;
  @override
  Future<void> saveProgression(ProgressionEntity value) async {
    progression = value;
  }
}

class _Si implements ISiRepository {
  @override
  Future<SiStateEntity?> getCurrentState() async => null;
  @override
  Future<void> saveState(SiStateEntity state) async {}
}

class _Learning extends LearningController {
  @override
  LearningState build() => const LearningState();

  @override
  Future<void> apply(LearningState updated) async {
    state = updated;
  }
}

class _Profile extends ProfileController {
  @override
  ProfileState build() => ProfileState();

  @override
  Future<void> awardXP(
    int amount, {
    required String source,
    bool Function()? shouldContinue,
  }) async {}
}

class _SiState extends SIStateController {
  @override
  SIState build() =>
      const SIState(energy: 0.8, fatigue: 0.2, completedToday: 0);
}

class _QuietLogs extends LogsActions {
  _QuietLogs(super.ref);
  @override
  Future<void> addMirroredEntry({
    required String source,
    required String message,
    String? id,
    DateTime? timestamp,
    bool Function()? shouldContinue,
  }) async {}
}

class _QuietTimeline extends TimelineActions {
  _QuietTimeline(super.ref);
  @override
  Future<void> addMirroredEvent(
    TimelineEventEntity event, {
    bool Function()? shouldContinue,
  }) async {}
}
