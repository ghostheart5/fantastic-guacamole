import 'package:fantastic_guacamole/core/network/network_status_service.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/domain/entities/learning_entity.dart';
import 'package:fantastic_guacamole/domain/entities/si_state_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task.dart';
import 'package:fantastic_guacamole/domain/entities/work_window_entity.dart';
import 'package:fantastic_guacamole/domain/operating_system/operating_system_contract.dart';
import 'package:fantastic_guacamole/domain/planning/planner_input.dart';
import 'package:fantastic_guacamole/engine/decision/decision_engine.dart';
import 'package:fantastic_guacamole/engine/si/models/si_state.dart';
import 'package:fantastic_guacamole/state/controllers/profile_controller.dart';
import 'package:fantastic_guacamole/state/models/progression_state.dart';
import 'package:fantastic_guacamole/state/models/si_pipeline_models.dart';
import 'package:fantastic_guacamole/state/models/signal_model.dart';
import 'package:fantastic_guacamole/state/models/signals_models.dart';
import 'package:fantastic_guacamole/state/models/trajectory_summary_view.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/execution_signals_provider.dart';
import 'package:fantastic_guacamole/state/providers/momentum_engine_provider.dart';
import 'package:fantastic_guacamole/state/providers/operating_system_provider.dart';
import 'package:fantastic_guacamole/state/providers/person_context_provider.dart';
import 'package:fantastic_guacamole/state/providers/progression_provider.dart';
import 'package:fantastic_guacamole/state/providers/si_pipeline_provider.dart';
import 'package:fantastic_guacamole/state/providers/storage_providers.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_consequence_provider.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

import 'trajectory_test_fixture.dart';

/// The signed-in account for a live trajectory container; tests switch it.
class TrajectoryLiveAccount extends Notifier<AccountStorageScope> {
  @override
  AccountStorageScope build() => AccountStorageScope.authenticated('account-a');

  void use(String userId) => state = AccountStorageScope.authenticated(userId);
}

final trajectoryLiveAccountProvider =
    NotifierProvider<TrajectoryLiveAccount, AccountStorageScope>(
      TrajectoryLiveAccount.new,
    );

/// SharedPreferences in memory, shared by every account in the container.
class TrajectoryMemoryStore implements SharedPrefsStore {
  final Map<String, String> values = <String, String>{};
  int saves = 0;

  @override
  Future<void> clear() async => values.clear();
  @override
  Future<void> delete(String key) async => values.remove(key);
  @override
  Future<void> init() async {}
  @override
  String? load(String key) => values[key];
  @override
  Future<void> save(String key, String value) async {
    saves++;
    values[key] = value;
  }
}

Task trajectoryLiveTask(String id, int minutes, {DateTime? dueDate}) => Task(
  id: id,
  title: 'Task $id',
  priority: 3,
  difficulty: 2,
  energyRequired: 2,
  dueDate: dueDate,
  estimatedDuration: Duration(minutes: minutes),
  createdAt: DateTime(2026, 11, 1),
);

/// A container that runs the real forecast providers (comparison, ledger,
/// calibration, engine model) over fixed inputs: a 240-minute observed work
/// window, [tasks], [completed7d] outcomes in the last 7 days, the clock
/// [clock] and an in-memory [store]. The account comes from
/// [trajectoryLiveAccountProvider].
ProviderContainer trajectoryLiveContainer({
  required DateTime now,
  required DateTime Function() clock,
  required TrajectoryMemoryStore store,
  List<Task>? tasks,
  int completed7d = 7,
  List<Override> overrides = const <Override>[],
}) {
  final List<Task> resolvedTasks =
      tasks ??
      <Task>[
        trajectoryLiveTask(
          'task-a',
          60,
          dueDate: DateTime(now.year, now.month, now.day + 5),
        ),
        trajectoryLiveTask('task-c', 30),
      ];
  final DecisionRecommendation decision = const DecisionEngine().recommend(
    inputs: PlannerInputAdapter.fromLegacyTasks(resolvedTasks),
    state: SiStateEntity(
      energy: .7,
      attention: .8,
      fatigue: .2,
      lastUpdated: now,
    ),
    learning: LearningEntity(),
    workWindows: <WorkWindowEntity>[
      WorkWindowEntity(
        id: 'window',
        start: now,
        end: now.add(const Duration(minutes: 240)),
      ),
    ],
    now: now,
  );
  final SIStateAggregation aggregation = SIStateAggregation(
    tasks: resolvedTasks,
    goals: const [],
    signals: const SignalsBundle(
      items: <Signal>[],
      summary: 'Stable',
      healthScore: .7,
    ),
    planningEvidence: const SIPlanningEvidence(
      friction: false,
      overwhelm: false,
      streakHealth: 'steady',
      goalDrift: false,
      taskAvoidance: false,
      emotion: 'neutral',
      emotionalStrain: false,
      emotionalStability: true,
      emotionalPatterns: <String>[],
    ),
    logs: const [],
    timeline: const [],
    memories: const [],
    notifications: const [],
    planPreview: const [],
    profile: ProfileState(),
    siState: const SIState(energy: .7, fatigue: .2),
    trajectory: _summary,
    planningDecision: decision,
    noContextPlanningDecision: decision,
  );
  return ProviderContainer(
    overrides: [
      accountStorageScopeProvider.overrideWith(
        (Ref ref) => ref.watch(trajectoryLiveAccountProvider),
      ),
      sharedPrefsStoreProvider.overrideWithValue(store),
      siStateAggregationProvider.overrideWith((Ref ref) async => aggregation),
      progressionProvider.overrideWithValue(ProgressionState.initial()),
      executionSignalsProvider.overrideWithValue(
        ExecutionSignals(
          createdToday: 0,
          completedToday: 0,
          skippedToday: 0,
          delayedToday: 0,
          created7d: completed7d,
          completed7d: completed7d,
          skipped7d: 0,
          delayed7d: 0,
        ),
      ),
      personContextForSurfaceProvider(
        trajectoryPersonContextRequest,
      ).overrideWithValue(null),
      trajectoryClockProvider.overrideWithValue(clock),
      trajectorySummaryProvider.overrideWithValue(trajectoryTestSummary()),
      momentumEngineProvider.overrideWithValue(trajectoryTestMomentum),
      decisionIntelligenceProvider.overrideWithValue(
        const AsyncLoading<DecisionIntelligence>(),
      ),
      networkInterfaceAvailabilityProvider.overrideWithValue(
        NetworkInterfaceAvailability.available,
      ),
      ...overrides,
    ],
  );
}

const TrajectorySummaryView _summary = TrajectorySummaryView(
  pendingTasks: 2,
  completedTasks: 7,
  completedToday: 0,
  level: 1,
  streak: 0,
  energy: .7,
  momentum: .5,
  adaptability: .5,
  lastCompletionXp: 0,
  lastCompletionQuality: 0,
  pressureIndex: 64,
  behaviorDivergence: 0,
  alert: '',
  predictionTitle: null,
  predictionOutcome: null,
  predictionProbability: null,
  predictionExplanation: null,
);
