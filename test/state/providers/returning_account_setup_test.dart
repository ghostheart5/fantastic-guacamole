import 'dart:async';

import 'package:fantastic_guacamole/app/router/route_paths.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_namespace.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/services/sync_service.dart';
import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_goal_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_habit_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
import 'package:fantastic_guacamole/domain/ports/notification_scheduler_port.dart';
import 'package:fantastic_guacamole/state/providers/account_onboarding_provider.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/daily_decision_intelligence_provider.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/settings_ui_provider.dart';
import 'package:fantastic_guacamole/state/providers/storage_providers.dart';
import 'package:fantastic_guacamole/state/providers/sync_provider.dart';
import 'package:fantastic_guacamole/tutorial/adaptive_guidance.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

/// A returning account on a new install: no setup or guidance state on this
/// device, but the account's own records are here (restored or already
/// stored). It must not be sent through setup and the first-run guide again.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test('an account with records on a new install skips setup and the '
      'first-run guide, and hints still appear', () async {
    final _Records records = _Records(
      tasks: <TaskEntity>[_task('done', completed: true)],
    );
    final _Harness app = _Harness(<String, _Records>{'returning': records});

    expect(await app.setupComplete(), isTrue);
    expect(await app.storedSetup('returning'), isTrue);

    final AdaptiveGuidanceState guide = await app.guide();
    expect(guide.coreComplete, isTrue);
    expect(guide.activeCoreLesson, isNull);
    expect(guide.coreGuideStatus, CoreGuideStatus.complete);
    expect(guide.has(GuidanceMilestone.firstTimelineReview), isTrue);
    expect(guide.has(GuidanceMilestone.replayed), isFalse);
    // A returning account did not just finish the guide: no quiet day.
    expect(guide.isInPostCoreQuietPeriod(DateTime.now()), isFalse);
    final GuidanceLesson? hint = guide.nextIntervention(
      currentRoute: RoutePaths.nexus,
      decision: _decision,
    );
    expect(hint?.hint, isNotNull, reason: 'Screen hints still appear once.');
  });

  test('records without a finished task skip setup and the guide but do not '
      'claim the schedule review', () async {
    final _Harness app = _Harness(<String, _Records>{
      'returning': _Records(habits: <HabitEntity>[_habit()]),
    });

    expect(await app.setupComplete(), isTrue);
    final AdaptiveGuidanceState guide = await app.guide();
    expect(guide.coreComplete, isTrue);
    expect(guide.activeCoreLesson, isNull);
    expect(guide.has(GuidanceMilestone.firstTimelineReview), isFalse);
  });

  test('a goal alone is a record of the account', () async {
    final _Harness app = _Harness(<String, _Records>{
      'returning': _Records(goals: <GoalEntity>[_goal()]),
    });
    expect(await app.setupComplete(), isTrue);
    expect((await app.guide()).coreComplete, isTrue);
  });

  test(
    'a new account with no records still gets setup and the guide',
    () async {
      final _Harness app = _Harness(<String, _Records>{'new': _Records()});

      expect(await app.setupComplete(), isFalse);
      expect(await app.storedSetup('new'), isNull, reason: 'Nothing recorded.');
      final AdaptiveGuidanceState guide = await app.guide();
      expect(guide.coreComplete, isFalse);
      expect(guide.activeCoreLesson, GuidanceLessonId.createFirstItem);
    },
  );

  test('setup finished on this install keeps the first-run guide of a new '
      'account that has since added a task', () async {
    final _Harness app = _Harness(
      <String, _Records>{
        'new': _Records(tasks: <TaskEntity>[_task('first')]),
      },
      prefs: <String, Object>{_setupKey('new'): true},
    );

    expect(await app.setupComplete(), isTrue);
    final AdaptiveGuidanceState guide = await app.guide();
    expect(guide.coreComplete, isFalse);
    expect(guide.has(GuidanceMilestone.returningAccount), isFalse);
  });

  test(
    'a restore that arrives after sign-in ends setup without a replay',
    () async {
      final _Records records = _Records();
      final _Harness app = _Harness(<String, _Records>{'returning': records});
      expect(await app.setupComplete(), isFalse);
      expect(
        (await app.guide()).activeCoreLesson,
        GuidanceLessonId.createFirstItem,
      );

      final List<AsyncValue<bool>> seen = <AsyncValue<bool>>[];
      app.container.listen(
        accountOnboardingCompleteProvider,
        (_, AsyncValue<bool> next) => seen.add(next),
      );
      app.restoreFills(
        records,
        tasks: <TaskEntity>[_task('restored', completed: true)],
      );
      expect(await app.container.read(restoreFromCloudProvider.future), isTrue);

      expect(
        app.container.read(accountOnboardingCompleteProvider).value,
        isTrue,
      );
      expect(await app.storedSetup('returning'), isTrue);
      expect(seen.any((AsyncValue<bool> value) => value.isLoading), isFalse);
      final AdaptiveGuidanceState guide = await app.guide();
      expect(guide.activeCoreLesson, isNull);
      expect(guide.replayLessons, isEmpty);
      expect(guide.has(GuidanceMilestone.replayed), isFalse);
      expect(guide.has(GuidanceMilestone.firstTimelineReview), isTrue);
    },
  );

  test('the inference is recorded once and never overrides an explicit '
      'restart of setup or of the guide', () async {
    final _Records records = _Records(tasks: <TaskEntity>[_task('task')]);
    final _Harness first = _Harness(<String, _Records>{'returning': records});
    expect(await first.setupComplete(), isTrue);
    final DateTime inferredAt =
        (await first.guide()).milestones[GuidanceMilestone.returningAccount]!;

    // The person restarts the guide, then setup, from Settings.
    await first.container
        .read(adaptiveGuidanceProvider.notifier)
        .restartLessons();
    expect(
      (await first.guide()).activeCoreLesson,
      GuidanceLessonId.createFirstItem,
    );
    await first.container
        .read(accountOnboardingCompleteProvider.notifier)
        .reset();
    expect(await first.storedSetup('returning'), isFalse);

    // Next launch, and a later restore, keep both restarts.
    final _Harness reopened = _Harness(<String, _Records>{
      'returning': records,
    });
    expect(await reopened.setupComplete(), isFalse);
    reopened.restoreFills(records, tasks: <TaskEntity>[_task('restored')]);
    expect(
      await reopened.container.read(restoreFromCloudProvider.future),
      isTrue,
    );
    expect(
      reopened.container.read(accountOnboardingCompleteProvider).value,
      isFalse,
    );
    final AdaptiveGuidanceState guide = await reopened.guide();
    expect(guide.activeCoreLesson, GuidanceLessonId.createFirstItem);
    expect(
      guide
          .milestones[GuidanceMilestone.returningAccount]
          ?.millisecondsSinceEpoch,
      inferredAt.millisecondsSinceEpoch,
    );
  });

  test('an explicit skip or pause of the guide stays as it was', () async {
    final _Records records = _Records();
    final _Harness app = _Harness(
      <String, _Records>{'returning': records},
      prefs: <String, Object>{_setupKey('returning'): true},
    );
    await app.guide();
    await app.container.read(adaptiveGuidanceProvider.notifier).skipCoreGuide();
    app.restoreFills(records, tasks: <TaskEntity>[_task('restored')]);
    expect(await app.container.read(restoreFromCloudProvider.future), isTrue);

    final AdaptiveGuidanceState guide = await app.guide();
    expect(guide.coreGuideStatus, CoreGuideStatus.skipped);
    expect(guide.has(GuidanceMilestone.returningAccount), isFalse);
  });

  test('an account switch does not carry the inference across', () async {
    final _Harness app = _Harness(<String, _Records>{
      'account-a': _Records(tasks: <TaskEntity>[_task('a')]),
      'account-b': _Records(),
    }, account: 'account-a');

    expect(await app.setupComplete(), isTrue);
    app.switchTo('account-b');
    expect(await app.setupComplete(), isFalse);
    expect(await app.storedSetup('account-b'), isNull);
    expect(
      (await app.guide()).activeCoreLesson,
      GuidanceLessonId.createFirstItem,
    );
    app.switchTo('account-a');
    expect(await app.setupComplete(), isTrue);
    expect((await app.guide()).coreComplete, isTrue);
  });

  test(
    'records read for one account are never applied after a switch',
    () async {
      final Completer<void> slowRead = Completer<void>();
      final _Harness app = _Harness(<String, _Records>{
        'account-a': _Records(tasks: <TaskEntity>[_task('a')], gate: slowRead),
        'account-b': _Records(),
      }, account: 'account-a');

      expect(await app.setupComplete(), isFalse);
      app.switchTo('account-b');
      expect(await app.setupComplete(), isFalse);
      slowRead.complete();
      await pumpEventQueue();

      expect(await app.storedSetup('account-a'), isNull);
      expect(await app.storedSetup('account-b'), isNull);
      expect(
        app.container.read(accountOnboardingCompleteProvider).value,
        isFalse,
      );
      expect(
        (await app.guide()).has(GuidanceMilestone.returningAccount),
        isFalse,
      );
    },
  );

  test('guidance stored by older versions loads unchanged', () async {
    final String prefix =
        'adaptive_guidance_v3.${AccountStorageScope.authenticated('older').v2Namespace}';
    final int at = DateTime.now().millisecondsSinceEpoch;
    final _Harness app = _Harness(
      <String, _Records>{'older': _Records()},
      prefs: <String, Object>{
        _setupKey('older'): true,
        '$prefix.firstItem.at': at,
        '$prefix.firstSchedule.at': at,
        '$prefix.firstTimelineReview.at': at,
      },
    );
    final AdaptiveGuidanceState guide = await app.guide();
    expect(guide.coreComplete, isTrue);
    expect(guide.has(GuidanceMilestone.returningAccount), isFalse);
    expect(guide.isInPostCoreQuietPeriod(DateTime.now()), isTrue);
  });
}

String _setupKey(String account) =>
    'onboarding_profile_complete_v1.'
    '${AccountStorageScope.authenticated(account).v2Namespace}';

class _Harness {
  _Harness(
    Map<String, _Records> records, {
    String? account,
    Map<String, Object> prefs = const <String, Object>{},
  }) {
    if (prefs.isNotEmpty) SharedPreferences.setMockInitialValues(prefs);
    _Records recordsOf(Ref ref) =>
        records[ref.watch(accountStorageScopeProvider).rawUserId] ?? _Records();
    container = ProviderContainer(
      overrides: [
        _scope.overrideWith(
          () => _ScopeNotifier(account ?? records.keys.first),
        ),
        accountStorageScopeProvider.overrideWith((ref) => ref.watch(_scope)),
        accountLegacyOwnershipProvider.overrideWithValue(
          LegacyScopeOwnership.ambiguous,
        ),
        domainTaskRepositoryProvider.overrideWith(recordsOf),
        domainHabitRepositoryProvider.overrideWith(recordsOf),
        domainGoalRepositoryProvider.overrideWith(recordsOf),
        cloudRestoreCapabilityProvider.overrideWithValue(true),
        cloudSyncPreferenceProvider.overrideWith(_OptedIn.new),
        supabaseClientProvider.overrideWithValue(_Client()),
        syncServiceProvider.overrideWith((ref) => _restore),
        restoredReminderReconciliationProvider.overrideWithValue(
          () async => NotificationScheduleResult.scheduled,
        ),
      ],
    );
    addTearDown(container.dispose);
  }

  late final ProviderContainer container;
  final _RestoreService _restore = _RestoreService();

  /// The setup answer once the account's records have been checked. The
  /// check runs after the first answer, so it never delays the router.
  Future<bool> setupComplete() async {
    await container.read(accountOnboardingCompleteProvider.future);
    await pumpEventQueue();
    return container.read(accountOnboardingCompleteProvider).value!;
  }

  Future<AdaptiveGuidanceState> guide() =>
      container.read(adaptiveGuidanceProvider.future);

  Future<bool?> storedSetup(String account) async =>
      (await SharedPreferences.getInstance()).getBool(_setupKey(account));

  void switchTo(String account) => container.read(_scope.notifier).set(account);

  /// The next cloud restore writes [tasks] into [records].
  void restoreFills(_Records records, {required List<TaskEntity> tasks}) {
    _restore.onRestore = () => records.tasks.addAll(tasks);
  }
}

final NotifierProvider<_ScopeNotifier, AccountStorageScope> _scope =
    NotifierProvider<_ScopeNotifier, AccountStorageScope>(
      () => _ScopeNotifier('unused'),
    );

class _ScopeNotifier extends Notifier<AccountStorageScope> {
  _ScopeNotifier(this.initial);
  final String initial;

  @override
  AccountStorageScope build() => AccountStorageScope.authenticated(initial);

  void set(String account) =>
      state = AccountStorageScope.authenticated(account);
}

class _Records implements ITaskRepository, IHabitRepository, IGoalRepository {
  _Records({
    List<TaskEntity>? tasks,
    this.habits = const <HabitEntity>[],
    this.goals = const <GoalEntity>[],
    this.gate,
  }) : tasks = tasks ?? <TaskEntity>[];

  final List<TaskEntity> tasks;
  final List<HabitEntity> habits;
  final List<GoalEntity> goals;
  final Completer<void>? gate;

  @override
  Future<List<TaskEntity>> getAllTasks() async {
    await gate?.future;
    return List<TaskEntity>.of(tasks);
  }

  @override
  Future<TaskEntity?> getTaskById(String id) async =>
      tasks.where((TaskEntity task) => task.id == id).firstOrNull;

  @override
  Future<void> saveTask(TaskEntity task) async {}

  @override
  Future<void> deleteTask(String id) async {}

  @override
  Future<List<HabitEntity>> getHabits() async => habits;

  @override
  Future<void> saveHabits(List<HabitEntity> habits) async {}

  @override
  List<GoalEntity> getGoals() => goals;

  @override
  Future<void> saveGoal(GoalEntity goal) async {}

  @override
  Future<void> saveGoals(List<GoalEntity> goals) async {}

  @override
  Future<void> deleteGoal(String id) async {}
}

TaskEntity _task(String id, {bool completed = false}) => TaskEntity(
  id: id,
  title: 'Task $id',
  createdAt: DateTime.utc(2026, 1, 2),
  scheduledFor: DateTime.utc(2026, 1, 3, 9),
  isCompleted: completed,
  completedAt: completed ? DateTime.utc(2026, 1, 3, 10) : null,
);

HabitEntity _habit() => HabitEntity(
  id: 'habit',
  title: 'Walk',
  createdAt: DateTime.utc(2026, 1, 2),
);

GoalEntity _goal() =>
    GoalEntity(id: 'goal', title: 'Run', createdAt: DateTime.utc(2026, 1, 2));

class _OptedIn extends CloudSyncPreferenceNotifier {
  @override
  Future<bool> build() async => true;
}

class _RestoreService implements SyncService {
  void Function()? onRestore;

  @override
  Future<CloudRestoreOutcome> restoreFromCloud() async {
    onRestore?.call();
    return CloudRestoreOutcome.restored;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Client implements sb.SupabaseClient {
  @override
  final sb.GoTrueClient auth = _Auth();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Auth implements sb.GoTrueClient {
  @override
  final sb.User currentUser = const sb.User(
    id: 'returning',
    appMetadata: <String, dynamic>{},
    userMetadata: null,
    aud: 'authenticated',
    createdAt: '2026-09-27T00:00:00Z',
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const DailyDecisionIntelligence _decision = DailyDecisionIntelligence(
  primaryAction: 'Work on Task A',
  momentum: '60% steady',
  trajectory: 'Stable',
  energy: '70% energy',
  warning: 'No material constraint is supported by the current evidence.',
  recovery: 'Protect a short recovery window.',
  recommendedAction: 'Work on Task A',
  rationale: 'Task A is the highest feasible item.',
  changeSummary: 'Task A moved up.',
  evidence: <String>['priority=5'],
  confidence: .7,
  observedOutcomes: 1,
);
