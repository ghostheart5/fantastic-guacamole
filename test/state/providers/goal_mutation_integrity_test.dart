import 'dart:async';
import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/state/providers/auth_session_boundary_provider.dart';
import 'package:fantastic_guacamole/state/providers/account_provider_fence.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/notification_entity.dart';
import 'package:fantastic_guacamole/domain/entities/si_state_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_goal_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_notification_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_si_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
import 'package:fantastic_guacamole/state/controllers/profile_controller.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/goals_provider.dart';
import 'package:fantastic_guacamole/state/providers/logs_provider.dart';
import 'package:fantastic_guacamole/state/providers/service_providers.dart';
import 'package:fantastic_guacamole/state/providers/timeline_provider.dart';
import 'package:fantastic_guacamole/state/services/notifications_service.dart';
import 'package:fantastic_guacamole/state/services/reminder_orchestrator_service.dart';
import 'package:fantastic_guacamole/state/state/logs_state.dart';
import 'package:fantastic_guacamole/system/notifications/notification_scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _fenceProvider = Provider<void Function()>(
  (ref) =>
      () => invalidateAccountOwnedProviders(ref),
);
void main() {
  for (final bool returnToOriginal in <bool>[false, true]) {
    for (final String action in <String>['create', 'update', 'complete']) {
      test(
        '$action cannot resume into another account or reopened session (return=$returnToOriginal)',
        () async {
          final f = _Fixture();
          addTearDown(f.container.dispose);
          final existing = GoalEntity(
            id: 'existing',
            title: 'Private A goal',
            createdAt: DateTime.utc(2026, 9, 8),
          );
          if (action != 'create') f.goalsA.goals.add(existing);
          final listener = f.container.listen(goalsProvider, (_, _) {});
          addTearDown(listener.close);
          f.goalsA.entered = Completer<void>();
          f.goalsA.release = Completer<void>();
          final notifier = f.container.read(goalsProvider.notifier);
          final Future<GoalMutationResult> saving = switch (action) {
            'create' => notifier.add(title: 'Private A goal'),
            'update' => notifier.update(
              existing.copyWith(title: 'Updated private goal'),
            ),
            _ => notifier.complete(existing.id),
          };
          await f.goalsA.entered!.future;
          await f.switchTo('account-b');
          if (returnToOriginal) await f.switchTo('account-a');
          f.goalsA.release!.complete();
          final result = await saving;
          await f.container.pump();
          expect(result.accountChanged, isTrue);
          expect(f.goalsA.goals, hasLength(1));
          expect(f.goalsB.goals, isEmpty);
          expect(f.logs.records, isEmpty);
          expect(f.timeline.events, isEmpty);
          expect(f.profile.awards, isEmpty);
          if (!returnToOriginal) {
            expect(f.container.read(goalsProvider), isEmpty);
          }
        },
      );
    }
  }
  test(
    'switch during reminder work stops remaining supporting updates',
    () async {
      final f = _Fixture();
      addTearDown(f.container.dispose);
      f.reminder.entered = Completer<void>();
      f.reminder.release = Completer<void>();
      final save = f.container
          .read(goalsProvider.notifier)
          .add(title: 'Private goal');
      await f.reminder.entered!.future;
      await f.switchTo('account-b');
      f.reminder.release!.complete();
      expect((await save).accountChanged, isTrue);
      expect(f.logs.records, isEmpty);
      expect(f.timeline.events, isEmpty);
      expect(f.profile.awards, isEmpty);
      expect(f.goalsB.goals, isEmpty);
    },
  );
  for (final String step in <String>[
    'reminders',
    'history',
    'timeline',
    'progress',
    'planner',
  ]) {
    test(
      'durable save with $step failure returns warning without inviting a retry',
      () async {
        final f = _Fixture();
        addTearDown(f.container.dispose);
        f.reminder.fail = step == 'reminders';
        f.logs.fail = step == 'history';
        f.timeline.fail = step == 'timeline';
        f.profile.fail = step == 'progress';
        f.si.fail = step == 'planner';
        late GoalMutationResult result;
        await Logger.withMutedErrors(() async {
          result = await f.container
              .read(goalsProvider.notifier)
              .add(title: 'One intended goal');
          await pumpEventQueue();
        });
        expect(result.warnings, contains(step));
        expect(result.accountChanged, isFalse);
        expect(f.goalsA.goals, hasLength(1));
        expect(f.goalsA.saveCalls, 1);
        expect(
          f.container.read(goalsProvider).single.title,
          'One intended goal',
        );
        if (step != 'history') expect(f.logs.records, hasLength(1));
        if (step != 'timeline') expect(f.timeline.events, hasLength(1));
        if (step != 'progress') expect(f.profile.awards, <int>[12]);
      },
    );
  }
  test(
    'canonical failure stays an error and emits no supporting history',
    () async {
      final f = _Fixture();
      addTearDown(f.container.dispose);
      f.goalsA.failSave = true;
      await expectLater(
        f.container.read(goalsProvider.notifier).add(title: 'Unsaved goal'),
        throwsStateError,
      );
      expect(f.goalsA.goals, isEmpty);
      expect(f.logs.records, isEmpty);
      expect(f.timeline.events, isEmpty);
      expect(f.profile.awards, isEmpty);
    },
  );

  test(
    'a completed goal with supporting failure cannot award completion XP twice',
    () async {
      final f = _Fixture();
      addTearDown(f.container.dispose);
      f.goalsA.goals.add(
        GoalEntity(
          id: 'existing',
          title: 'One completion',
          createdAt: DateTime.utc(2026, 9, 8),
        ),
      );
      f.logs.fail = true;
      final notifier = f.container.read(goalsProvider.notifier);
      await Logger.withMutedErrors(() async {
        final result = await notifier.complete('existing');
        expect(result.warnings, contains('history'));
        expect(f.container.read(goalsProvider), isEmpty);
        await notifier.complete('existing');
      });
      expect(f.goalsA.goals.single.isCompleted, isTrue);
      expect(f.profile.awards, <int>[40]);
      expect(f.timeline.events, hasLength(1));
    },
  );

  test(
    'simultaneous delayed completions share one save and one XP award',
    () async {
      final f = _Fixture();
      addTearDown(f.container.dispose);
      f.goalsA.goals.add(
        GoalEntity(
          id: 'existing',
          title: 'One completion',
          createdAt: DateTime.utc(2026, 9, 8),
        ),
      );
      f.goalsA.entered = Completer<void>();
      f.goalsA.release = Completer<void>();
      final notifier = f.container.read(goalsProvider.notifier);
      final first = notifier.complete('existing');
      await f.goalsA.entered!.future;
      final second = notifier.complete('existing');
      await pumpEventQueue();
      expect(f.goalsA.saveCalls, 1);
      f.goalsA.release!.complete();
      final results = await Future.wait(<Future<GoalMutationResult>>[
        first,
        second,
      ]);
      expect(results.every((r) => !r.hasWarnings && !r.accountChanged), isTrue);
      expect(f.goalsA.goals.single.isCompleted, isTrue);
      expect(f.profile.awards, <int>[40]);
      expect(f.timeline.events, hasLength(1));
      expect(f.logs.records, hasLength(1));
    },
  );
}

class _Fixture {
  _Fixture() {
    container = ProviderContainer(
      overrides: [
        accountStorageScopeProvider.overrideWith((ref) => scope),
        domainGoalRepositoryProvider.overrideWith(
          (ref) =>
              ref.watch(accountStorageScopeProvider).rawUserId == 'account-a'
              ? goalsA
              : goalsB,
        ),
        domainTaskRepositoryProvider.overrideWithValue(_FakeTaskRepository([])),
        domainSiRepositoryProvider.overrideWithValue(si),
        reminderOrchestratorServiceProvider.overrideWithValue(reminder),
        logsProvider.overrideWith(() => logs),
        timelineProvider.overrideWith(() => timeline),
        profileProvider.overrideWith(() => profile),
      ],
    );
  }
  AccountStorageScope scope = AccountStorageScope.authenticated('account-a');
  late final ProviderContainer container;
  final goalsA = _FakeGoalRepository([]);
  final goalsB = _FakeGoalRepository([]);
  final logs = _RecordingLogs();
  final timeline = _RecordingTimeline();
  final profile = _RecordingProfile();
  final reminder = _ControlledReminder();
  final si = _EmptySiRepository();
  Future<void> switchTo(String userId) async {
    final boundary = container.read(authSessionBoundaryProvider.notifier);
    final generation = boundary.begin(userId: userId, isTransitioning: true);
    boundary.complete(generation);
    scope = AccountStorageScope.authenticated(userId);
    container.invalidate(accountStorageScopeProvider);
    container.read(_fenceProvider)();
    await container.pump();
    container.read(goalsProvider);
  }
}

class _ControlledReminder extends ReminderOrchestratorService {
  _ControlledReminder()
    : super(
        preferences: _DisabledPreferences(),
        notifications: NotificationsService(_NoopNotifications()),
        scheduler: NotificationScheduler(),
        accountScope: null,
      );
  bool fail = false;
  Completer<void>? entered;
  Completer<void>? release;
  @override
  Future<void> syncGoalReminders(
    List<GoalEntity> goals, {
    bool Function()? shouldContinue,
  }) async {
    if (goals.isEmpty || shouldContinue?.call() == false) return;
    if (fail) throw StateError('Reminder failure');
    if (entered != null && !entered!.isCompleted) entered!.complete();
    await release?.future;
  }

  @override
  Future<void> ensureDailyPlanningReminder({
    bool Function()? shouldContinue,
  }) async {}
}

final class _FakeGoalRepository implements IGoalRepository {
  _FakeGoalRepository(List<GoalEntity> goals)
    : goals = List<GoalEntity>.from(goals);

  final List<GoalEntity> goals;
  int saveCalls = 0;
  Completer<void>? entered;
  Completer<void>? release;
  bool failSave = false;

  @override
  Future<void> deleteGoal(String id) async {
    goals.removeWhere((GoalEntity goal) => goal.id == id);
  }

  @override
  List<GoalEntity> getGoals() => List<GoalEntity>.unmodifiable(goals);

  @override
  Future<void> saveGoal(GoalEntity goal) async {
    saveCalls += 1;
    if (failSave) throw StateError('Canonical save failure');
    if (entered != null && !entered!.isCompleted) entered!.complete();
    await release?.future;
    final int index = goals.indexWhere((GoalEntity item) => item.id == goal.id);
    if (index < 0) {
      goals.add(goal);
    } else {
      goals[index] = goal;
    }
  }

  @override
  Future<void> saveGoals(List<GoalEntity> goals) async {
    saveCalls += 1;
    this.goals
      ..clear()
      ..addAll(goals);
  }
}

final class _FakeTaskRepository implements ITaskRepository {
  _FakeTaskRepository(this.tasks);

  final List<TaskEntity> tasks;

  @override
  Future<void> deleteTask(String id) async {}

  @override
  Future<List<TaskEntity>> getAllTasks() async => tasks;

  @override
  Future<TaskEntity?> getTaskById(String id) async => null;

  @override
  Future<void> saveTask(TaskEntity task) async {}
}

final class _EmptySiRepository implements ISiRepository {
  bool fail = false;
  @override
  Future<SiStateEntity?> getCurrentState() async {
    if (fail) throw StateError('Injected planner failure');
    return null;
  }

  @override
  Future<void> saveState(SiStateEntity state) async {}
}

final class _RecordingLogs extends LogsController {
  bool fail = false;
  final List<({String source, String message})> records =
      <({String source, String message})>[];

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
  }) async {
    if (shouldContinue?.call() == false) return;
    if (fail) throw StateError('History failure');
    records.add((source: source, message: message));
  }
}

final class _RecordingTimeline extends TimelineNotifier {
  bool fail = false;
  final List<TimelineEventEntity> events = <TimelineEventEntity>[];

  @override
  List<TimelineEventEntity> build() => const <TimelineEventEntity>[];

  @override
  Future<void> record(
    TimelineEventEntity event, {
    bool refreshPlanner = true,
    bool awardProgression = false,
    bool Function()? shouldContinue,
  }) async {
    if (shouldContinue?.call() == false) return;
    if (fail) throw StateError('Timeline failure');
    events.add(event);
  }
}

final class _RecordingProfile extends ProfileController {
  bool fail = false;
  final List<int> awards = <int>[];

  @override
  ProfileState build() => ProfileState();

  @override
  Future<void> awardXP(
    int amount, {
    required String source,
    bool Function()? shouldContinue,
  }) async {
    if (shouldContinue?.call() == false) return;
    if (fail) throw StateError('Progress failure');
    awards.add(amount);
  }
}

final class _DisabledPreferences implements SharedPrefsStore {
  @override
  Future<void> clear() async {}

  @override
  Future<void> delete(String key) async {}

  @override
  Future<void> init() async {}

  @override
  String? load(String key) => 'false';

  @override
  Future<void> save(String key, String value) async {}
}

final class _NoopNotifications implements INotificationRepository {
  @override
  Future<void> cancelNotification(String id) async {}

  @override
  Future<void> delete(String id) async {}

  @override
  Future<List<NotificationEntity>> getNotifications() async =>
      const <NotificationEntity>[];

  @override
  Future<void> markRead(String id) async {}

  @override
  Future<void> scheduleNotification(NotificationEntity notification) async {}
}
