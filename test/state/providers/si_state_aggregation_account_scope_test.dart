import 'dart:async';

import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/di/storage_providers.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/data/repositories/habit_repository.dart';
import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/memory_entity.dart';
import 'package:fantastic_guacamole/domain/entities/notification_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
import 'package:fantastic_guacamole/engine/learning/learning_state.dart';
import 'package:fantastic_guacamole/engine/si/models/si_state.dart';
import 'package:fantastic_guacamole/state/controllers/learning_controller.dart';
import 'package:fantastic_guacamole/state/controllers/profile_controller.dart';
import 'package:fantastic_guacamole/state/controllers/si_state_controller.dart';
import 'package:fantastic_guacamole/state/models/core_values_models.dart';
import 'package:fantastic_guacamole/state/models/insights_models.dart';
import 'package:fantastic_guacamole/state/models/progression_state.dart';
import 'package:fantastic_guacamole/state/models/soul_map_models.dart';
import 'package:fantastic_guacamole/state/models/trajectory_summary_view.dart';
import 'package:fantastic_guacamole/state/models/si_pipeline_models.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/core_values_provider.dart';
import 'package:fantastic_guacamole/state/providers/energy_provider.dart';
import 'package:fantastic_guacamole/state/providers/emotion_provider.dart';
import 'package:fantastic_guacamole/state/providers/explainable_si_provider.dart';
import 'package:fantastic_guacamole/state/providers/execution_signals_provider.dart';
import 'package:fantastic_guacamole/state/providers/habits_provider.dart';
import 'package:fantastic_guacamole/state/providers/goals_provider.dart';
import 'package:fantastic_guacamole/state/providers/insights_provider.dart';
import 'package:fantastic_guacamole/state/providers/logs_provider.dart';
import 'package:fantastic_guacamole/state/providers/memories_provider.dart';
import 'package:fantastic_guacamole/state/providers/notification_provider.dart';
import 'package:fantastic_guacamole/state/providers/momentum_engine_provider.dart';
import 'package:fantastic_guacamole/state/providers/progression_provider.dart';
import 'package:fantastic_guacamole/state/providers/si_pipeline_provider.dart';
import 'package:fantastic_guacamole/state/providers/soul_map_provider.dart';
import 'package:fantastic_guacamole/state/providers/task_provider.dart';
import 'package:fantastic_guacamole/state/providers/timeline_provider.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_provider.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/app_integration_actions_provider.dart';
import 'package:fantastic_guacamole/state/providers/supabase_backend_provider.dart';
import 'package:fantastic_guacamole/state/services/app_integration_actions.dart';
import 'package:fantastic_guacamole/features/monetization/integration/monetization_actions_compat.dart';
import 'package:fantastic_guacamole/state/state/logs_state.dart';
import 'package:fantastic_guacamole/state/state/emotional_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _scopeProvider = NotifierProvider<_ScopeNotifier, AccountStorageScope>(
  _ScopeNotifier.new,
);

void main() {
  test('real SI aggregation projects only the current account fixture', () async {
    final SiAggregationAccountFixture fixture = SiAggregationAccountFixture();
    final ProviderContainer container = fixture.createContainer();
    addTearDown(container.dispose);

    fixture.activate('A');
    final ProviderSubscription<AsyncValue<List<dynamic>>> taskSubscription =
        container.listen(tasksProvider, (_, _) {}, fireImmediately: true);
    addTearDown(taskSubscription.close);
    await container.read(tasksProvider.future);
    final aggregationA = await _readFor(container, 'A_PROFILE');
    _expectOnly(aggregationA, 'A');

    fixture.signOut();
    final signedOut = await _readFor(container, 'signed_out');
    _expectEmpty(signedOut);

    fixture.activate('B');
    final aggregationB = await _readFor(container, 'B_PROFILE');
    _expectOnly(aggregationB, 'B');

    fixture.signOut();
    _expectEmpty(await _readFor(container, 'signed_out'));
    fixture.activate('A');
    _expectOnly(await _readFor(container, 'A_PROFILE'), 'A');

    fixture.activate('C');
    _expectOnly(await _readFor(container, 'C_PROFILE'), 'C');
  });

  test('real decision and Nexus model project only the current account fixture', () async {
    final SiAggregationAccountFixture fixture = SiAggregationAccountFixture();
    final ProviderContainer container = fixture.createContainer();
    addTearDown(container.dispose);

    fixture.activate('A');
    final SIDecisionOutput aDecision = await _readDecisionFor(container, 'A_DECISION_TASK');
    final NexusScreenModel aModel = await _readNexusFor(container, 'A_DECISION_TASK');
    expect(aDecision.nextAction, 'A_DECISION_TASK');
    expect(aModel.aggregation.tasks.single.title, 'A_TASK');
    expect(aModel.decision.nextAction, 'A_DECISION_TASK');

    fixture.signOut();
    final SIDecisionOutput signedOutDecision = await _readDecisionFor(container, 'Capture one high-value task.');
    final NexusScreenModel signedOutModel = await _readNexusFor(container, 'Capture one high-value task.');
    expect(signedOutModel.aggregation.profile.name, 'signed_out');
    expect(signedOutModel.aggregation.tasks, isEmpty);
    expect(signedOutDecision.nextAction, isNot(contains('A_')));

    fixture.activate('B');
    final SIDecisionOutput bDecision = await _readDecisionFor(container, 'B_DECISION_TASK');
    final NexusScreenModel bModel = await _readNexusFor(container, 'B_DECISION_TASK');
    expect(bDecision.nextAction, 'B_DECISION_TASK');
    expect(bModel.aggregation.tasks.single.title, 'B_TASK');
    expect(bModel.decision.nextAction, isNot(contains('A_')));

    fixture.signOut();
    fixture.activate('A');
    final NexusScreenModel restoredA = await _readNexusFor(container, 'A_DECISION_TASK');
    expect(restoredA.aggregation.tasks.single.title, 'A_TASK');
    expect(restoredA.decision.nextAction, isNot(contains('B_')));

    fixture.signOut();
    fixture.activate('C');
    final NexusScreenModel cModel = await _readNexusFor(container, 'C_DECISION_TASK');
    expect(cModel.aggregation.tasks.single.title, 'C_TASK');
    expect(cModel.decision.nextAction, isNot(anyOf(contains('A_'), contains('B_'))));
  });

  test('integrated Nexus inputs and real derived graph remain account-local', () async {
    final SiAggregationAccountFixture fixture = SiAggregationAccountFixture();
    final ProviderContainer container = fixture.createContainer();
    addTearDown(container.dispose);

    fixture.activate('A');
    await _expectIntegrated(container, 'A');
    fixture.signOut();
    await _expectSignedOutIntegrated(container);
    fixture.activate('B');
    await _expectIntegrated(container, 'B');
    fixture.signOut();
    fixture.activate('A');
    await _expectIntegrated(container, 'A');
    fixture.signOut();
    fixture.activate('C');
    await _expectIntegrated(container, 'C');
  });
}

Future<void> _expectIntegrated(ProviderContainer container, String account) async {
  expect((await container.read(habitsProvider.future)).single.title, '${account}_HABIT');
  expect(container.read(progressionProvider).error, '${account}_PROGRESSION');
  expect(container.read(unreadNotificationsProvider), account == 'A' ? 7 : account == 'B' ? 2 : 4);
  expect(container.read(nexusStartupSummaryProvider).startupDirective, '${account}_STARTUP');
  expect(container.read(momentumEngineProvider).energyPercent, 70);
  final NexusScreenModel model = await _readNexusFor(container, '${account}_DECISION_TASK');
  expect(model.aggregation.tasks.single.title, '${account}_TASK');
  expect(model.decision.nextAction, '${account}_DECISION_TASK');
}

Future<void> _expectSignedOutIntegrated(ProviderContainer container) async {
  expect(await container.read(habitsProvider.future), isEmpty);
  expect(container.read(progressionProvider).error, isNull);
  expect(container.read(unreadNotificationsProvider), 0);
  expect(container.read(nexusStartupSummaryProvider).startupDirective, 'SIGNED_OUT_STARTUP');
  expect(container.read(momentumEngineProvider).score, isNot(100));
  final NexusScreenModel model = await _readNexusFor(container, 'Capture one high-value task.');
  expect(model.aggregation.tasks, isEmpty);
  expect(model.aggregation.profile.name, 'signed_out');
}

Future<SIStateAggregation> _readFor(
  ProviderContainer container,
  String expectedProfile,
) async {
  final Completer<SIStateAggregation> result = Completer<SIStateAggregation>();
  late ProviderSubscription<AsyncValue<SIStateAggregation>> subscription;
  subscription = container.listen(
    siStateAggregationProvider,
    (_, AsyncValue<SIStateAggregation> next) {
      if (next.hasValue &&
          next.requireValue.profile.name == expectedProfile &&
          !result.isCompleted) {
        result.complete(next.requireValue);
      }
      if (next.hasError && !result.isCompleted) {
        result.completeError(next.error!, next.stackTrace);
      }
    },
    fireImmediately: true,
  );
  try {
    return await result.future.timeout(const Duration(seconds: 3));
  } finally {
    subscription.close();
  }
}

Future<SIDecisionOutput> _readDecisionFor(
  ProviderContainer container,
  String expectedAction,
) async {
  final Completer<SIDecisionOutput> result = Completer<SIDecisionOutput>();
  late ProviderSubscription<AsyncValue<SIDecisionOutput>> subscription;
  subscription = container.listen(
    siDecisionOutputProvider,
    (_, AsyncValue<SIDecisionOutput> next) {
      if (next.hasValue && next.requireValue.nextAction == expectedAction && !result.isCompleted) {
        result.complete(next.requireValue);
      }
      if (next.hasError && !result.isCompleted) result.completeError(next.error!, next.stackTrace);
    },
    fireImmediately: true,
  );
  try {
    return await result.future.timeout(const Duration(seconds: 3));
  } finally {
    subscription.close();
  }
}

Future<NexusScreenModel> _readNexusFor(
  ProviderContainer container,
  String expectedAction,
) async {
  final Completer<NexusScreenModel> result = Completer<NexusScreenModel>();
  late ProviderSubscription<AsyncValue<NexusScreenModel>> subscription;
  subscription = container.listen(
    nexusScreenModelProvider,
    (_, AsyncValue<NexusScreenModel> next) {
      if (next.hasValue && next.requireValue.decision.nextAction == expectedAction && !result.isCompleted) {
        result.complete(next.requireValue);
      }
      if (next.hasError && !result.isCompleted) result.completeError(next.error!, next.stackTrace);
    },
    fireImmediately: true,
  );
  try {
    return await result.future.timeout(const Duration(seconds: 3));
  } finally {
    subscription.close();
  }
}

void _expectOnly(SIStateAggregation aggregation, String account) {
  final String other = account == 'A' ? 'B' : 'A';
  expect(aggregation.tasks.single.title, '${account}_TASK');
  expect(aggregation.goals.single.title, '${account}_GOAL');
  expect(aggregation.profile.name, '${account}_PROFILE');
  expect(aggregation.memories.single.text, '${account}_MEMORY');
  expect(aggregation.notifications.single.title, '${account}_NOTIFICATION');
  expect(aggregation.soulMap.recommendations, contains('${account}_SOULMAP_ALIGNMENT'));
  expect(aggregation.trajectory.alert, '${account}_TRAJECTORY');
  expect(aggregation.tasks.single.title, isNot(contains('${other}_')));
  expect(aggregation.profile.name, isNot(contains('${other}_')));
}

void _expectEmpty(SIStateAggregation aggregation) {
  expect(aggregation.tasks, isEmpty);
  expect(aggregation.goals, isEmpty);
  expect(aggregation.memories, isEmpty);
  expect(aggregation.notifications, isEmpty);
  expect(aggregation.profile.name, 'signed_out');
  expect(aggregation.soulMap.recommendations, isEmpty);
}

class _ScopeNotifier extends Notifier<AccountStorageScope> {
  @override
  AccountStorageScope build() => const AccountStorageScope.signedOut();

  void set(AccountStorageScope value) => state = value;
}

class SiAggregationAccountFixture {
  late ProviderContainer _container;

  void activate(String userId) {
    _container.read(_scopeProvider.notifier).set(AccountStorageScope.authenticated(userId));
  }

  void signOut() => _container.read(_scopeProvider.notifier).set(const AccountStorageScope.signedOut());

  ProviderContainer createContainer() {
    final _ScopedTaskRepository repository = _ScopedTaskRepository(() => _container.read(_scopeProvider));
    _container = ProviderContainer(overrides: [
      accountStorageScopeProvider.overrideWith((Ref ref) => ref.watch(_scopeProvider)),
      secureStoreProvider.overrideWithValue(SecureStore(backend: InMemorySecureStoreBackend())),
      domainTaskRepositoryProvider.overrideWithValue(repository),
      domainSiDecisionProvider.overrideWith((Ref ref) async {
        final scope = ref.watch(_scopeProvider);
        if (!scope.isAuthenticated) return null;
        return Task(
          id: 'shared-decision-task',
          title: '${scope.rawUserId}_DECISION_TASK',
          priority: 1,
          difficulty: 1,
          energyRequired: 1,
        );
      }),
      tasksProvider.overrideWith((Ref ref) async {
        ref.watch(_scopeProvider);
        return const [];
      }),
      goalsProvider.overrideWith(() => _ScopedGoalsNotifier()),
      memoriesProvider.overrideWith(() => _ScopedMemoriesNotifier()),
      notificationProvider.overrideWith(() => _ScopedNotificationNotifier()),
      habitsProvider.overrideWith(() => _ScopedHabitsNotifier()),
      profileProvider.overrideWith(() => _ScopedProfileController()),
      siStateProvider.overrideWith(() => _ScopedSiStateController()),
      emotionProvider.overrideWith(() => _ScopedEmotionNotifier()),
      insightsBundleProvider.overrideWith((Ref ref) {
        final scope = ref.watch(_scopeProvider);
        return InsightsBundle(items: const [], summary: scope.isAuthenticated ? '${scope.rawUserId}_INSIGHT' : '', healthScore: 0);
      }),
      logsProvider.overrideWith(() => _StaticLogsController()),
      timelineProvider.overrideWith(() => _StaticTimelineNotifier()),
      trajectorySummaryProvider.overrideWith((Ref ref) => _trajectory(ref.watch(_scopeProvider))),
      coreValuesAlignmentProvider.overrideWithValue(_coreValues),
      soulMapAlignmentProvider.overrideWith((Ref ref) => _soulMap(ref.watch(_scopeProvider))),
      executionSignalsProvider.overrideWith((Ref ref) => _executionFor(ref.watch(_scopeProvider))),
      extendedDomainBootstrapProvider.overrideWith((Ref ref) async {
        ref.watch(_scopeProvider);
      }),
      explainableSIProvider.overrideWith(
        (Ref ref) => _explainableFor(ref.watch(_scopeProvider)),
      ),
      progressionProvider.overrideWith((Ref ref) => _progressionFor(ref.watch(_scopeProvider))),
      unreadNotificationsProvider.overrideWith((Ref ref) => _unreadFor(ref.watch(_scopeProvider))),
      nexusStartupSummaryProvider.overrideWith((Ref ref) => _startupFor(ref.watch(_scopeProvider))),
      energyProvider.overrideWithValue(.7),
      learningProvider.overrideWith(() => _ScopedLearningController()),
      appIntegrationActionsProvider.overrideWith(_FixtureIntegrationActions.new),
    ]);
    return _container;
  }
}

class _ScopedTaskRepository implements ITaskRepository {
  _ScopedTaskRepository(this._scope);
  final AccountStorageScope Function() _scope;
  @override Future<List<TaskEntity>> getAllTasks() async {
    final scope = _scope();
    if (!scope.isAuthenticated) return const [];
    return [TaskEntity(id: 'shared-task', title: '${scope.rawUserId}_TASK', createdAt: DateTime(2026), estimatedDuration: const Duration(minutes: 25))];
  }
  @override Future<TaskEntity?> getTaskById(String id) async => null;
  @override Future<void> saveTask(TaskEntity task) async {}
  @override Future<void> deleteTask(String id) async {}
}

class _ScopedGoalsNotifier extends GoalsNotifier {
  @override List<GoalEntity> build() {
    final scope = ref.watch(_scopeProvider);
    return scope.isAuthenticated ? [GoalEntity(id: 'shared-goal', title: '${scope.rawUserId}_GOAL', createdAt: DateTime(2026))] : const [];
  }
}
class _ScopedMemoriesNotifier extends MemoriesNotifier {
  @override List<MemoryEntity> build() {
    final scope = ref.watch(_scopeProvider);
    return scope.isAuthenticated ? [MemoryEntity(id: 'shared-memory', text: '${scope.rawUserId}_MEMORY', date: DateTime(2026), category: MemoryCategory.journal)] : const [];
  }
}
class _ScopedNotificationNotifier extends NotificationNotifier {
  @override List<NotificationEntity> build() {
    final scope = ref.watch(_scopeProvider);
    return scope.isAuthenticated ? [NotificationEntity(id: 'shared-notification', title: '${scope.rawUserId}_NOTIFICATION', message: '', scheduledAt: DateTime(2026))] : const [];
  }
}
class _ScopedHabitsNotifier extends HabitsNotifier { @override Future<List<HabitRecord>> build() async { final scope = ref.watch(_scopeProvider); return scope.isAuthenticated ? [HabitRecord(id: 'shared-habit', title: '${scope.rawUserId}_HABIT')] : const []; } }
class _ScopedProfileController extends ProfileController {
  @override ProfileState build() {
    final scope = ref.watch(_scopeProvider);
    return ProfileState(name: scope.isAuthenticated ? '${scope.rawUserId}_PROFILE' : 'signed_out', profileReady: scope.isAuthenticated);
  }
}
class _ScopedSiStateController extends SIStateController {
  @override
  SIState build() {
    final scope = ref.watch(_scopeProvider);
    return switch (scope.rawUserId) {
      'A' => const SIState(energy: .7, fatigue: .3, completedToday: 3),
      'B' => const SIState(energy: .7, fatigue: .58, completedToday: 1),
      'C' => const SIState(energy: .7, fatigue: .37, completedToday: 2),
      _ => const SIState(energy: .5, fatigue: .5),
    };
  }
}
class _ScopedEmotionNotifier extends EmotionNotifier {
  @override
  EmotionalState build() => switch (ref.watch(_scopeProvider).rawUserId) {
    'A' => EmotionalState.focused,
    'B' => EmotionalState.calm,
    'C' => EmotionalState.energized,
    _ => EmotionalState.neutral,
  };
}
class _StaticLogsController extends LogsController { @override LogsState build() => LogsState.initial(); }
class _StaticTimelineNotifier extends TimelineNotifier { @override List<TimelineEventEntity> build() => const []; }
class _ScopedLearningController extends LearningController { @override LearningState build() { final scope = ref.watch(_scopeProvider); return LearningState(completed: scope.isAuthenticated ? 1 : 0, taskAffinity: scope.isAuthenticated ? {'${scope.rawUserId}_LEARNING': 1} : const {}); } }
class _FixtureIntegrationActions extends AppIntegrationActions {
  const _FixtureIntegrationActions(super.ref);
  @override
  Future<AppIntegrationSnapshot> fetchIntegrationSnapshot() async => const AppIntegrationSnapshot(
    currentUserId: null,
    supabaseHealth: SupabaseBackendHealth(configured: false, initialized: false, authenticated: false, databaseReachable: false, storageReachable: false, realtimeConfigured: false, badge: SupabaseHealthBadge.connectivityIssue, message: 'fixture'),
    syncErrorMessage: null,
    offlineQueueCount: 0,
    monetizationStatus: MonetizationStatusSnapshot(planId: 'fixture', isPremium: false, isActive: false, walletBalance: 0, stackType: MonetizationStackType.feature),
  );
}

ExecutionSignals _executionFor(AccountStorageScope scope) => ExecutionSignals(createdToday: 0, completedToday: scope.isAuthenticated ? 2 : 0, skippedToday: 0, delayedToday: 0, created7d: 0, completed7d: scope.isAuthenticated ? 2 : 0, skipped7d: 0, delayed7d: 0);
ExplainableSIState _explainableFor(AccountStorageScope scope) {
  final value = scope.isAuthenticated
      ? '${scope.rawUserId}_EXPLAINABLE_SI'
      : 'SIGNED_OUT_EXPLAINABLE_SI';
  return ExplainableSIState(
    primaryReason: value,
    recommendation: value,
    reasons: <ExplainableSIReason>[
      ExplainableSIReason(
        label: 'shared-explanation',
        detail: value,
        severity: ExplainableSISeverity.neutral,
      ),
    ],
  );
}
ProgressionState _progressionFor(AccountStorageScope scope) => scope.isAuthenticated ? ProgressionState(progress: ProgressionState.initial().progress, loading: false, error: '${scope.rawUserId}_PROGRESSION') : ProgressionState.initial();
int _unreadFor(AccountStorageScope scope) => switch (scope.rawUserId) { 'A' => 7, 'B' => 2, 'C' => 4, _ => 0 };
NexusStartupSummary _startupFor(AccountStorageScope scope) => NexusStartupSummary(profile: ProfileState(name: scope.isAuthenticated ? '${scope.rawUserId}_PROFILE' : 'signed_out', profileReady: scope.isAuthenticated), energy: scope.isAuthenticated ? .7 : 0, fatigue: 0, completedToday: 0, emotionLabel: scope.isAuthenticated ? 'focused' : 'signed_out', startupDirective: scope.isAuthenticated ? '${scope.rawUserId}_STARTUP' : 'SIGNED_OUT_STARTUP');
final CoreValuesAlignment _coreValues = const CoreValuesAlignment(scores: {}, overall: 0, strongest: CoreValueType.clarity, mostNeglected: CoreValueType.clarity, recommendations: [], selectedValues: {});
TrajectorySummaryView _trajectory(AccountStorageScope scope) => TrajectorySummaryView(pendingTasks: 0, completedTasks: 0, completedToday: 0, level: 1, streak: 0, energy: .7, momentum: 0, adaptability: 0, lastSessionXp: 0, lastSessionQuality: 0, pressureIndex: 0, behaviorDivergence: 0, alert: scope.isAuthenticated ? '${scope.rawUserId}_TRAJECTORY' : '', predictionTitle: null, predictionOutcome: null, predictionProbability: null, predictionExplanation: null);
SoulMapAlignment _soulMap(AccountStorageScope scope) => SoulMapAlignment(scores: const {}, overall: 0, strongest: SoulMapDimension.purpose, weakest: SoulMapDimension.purpose, recommendations: scope.isAuthenticated ? ['${scope.rawUserId}_SOULMAP_ALIGNMENT'] : const []);
