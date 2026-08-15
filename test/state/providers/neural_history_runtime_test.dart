import 'dart:async';

import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/di/storage_providers.dart';
import 'package:fantastic_guacamole/data/storage/neural_history_store.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
import 'package:fantastic_guacamole/domain/usecases/complete_task.dart';
import 'package:fantastic_guacamole/engine/si/prediction.dart';
import 'package:fantastic_guacamole/engine/learning/neural_dump.dart';
import 'package:fantastic_guacamole/engine/si/models/si_state.dart';
import 'package:fantastic_guacamole/engine/learning/learning_metrics.dart';
import 'package:fantastic_guacamole/engine/learning/learning_state.dart';
import 'package:fantastic_guacamole/domain/entities/task.dart';
import 'package:fantastic_guacamole/state/controllers/ai_controller.dart';
import 'package:fantastic_guacamole/state/controllers/insight_controller.dart';
import 'package:fantastic_guacamole/state/controllers/prediction_controller.dart';
import 'package:fantastic_guacamole/state/controllers/learning_controller.dart';
import 'package:fantastic_guacamole/state/controllers/profile_controller.dart';
import 'package:fantastic_guacamole/state/controllers/si_state_controller.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/neural_history_provider.dart';
import 'package:fantastic_guacamole/state/providers/task_provider.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_provider.dart';
import 'package:fantastic_guacamole/state/models/trajectory_summary_view.dart';
import 'package:fantastic_guacamole/state/providers/learning_history_provider.dart';
import 'package:fantastic_guacamole/state/providers/execution_signals_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/controllable_secure_store_backend.dart';

void main() {
  test('real AI producer and prediction/insight readers remain account scoped',
      () async {
    final ControllableSecureStoreBackend backend =
        ControllableSecureStoreBackend();
    final SecureStore secureStore = SecureStore(backend: backend);
    final ProviderContainer container = _container(secureStore);
    addTearDown(container.dispose);

    container.read(_scopeProvider.notifier).setAuthenticated('A');
    await container.read(aiControllerProvider).appendNeuralDumpEntry(
          task: 'shared-task',
          reasoning: 'A_SECRET_NEURAL_REASONING',
          confidence: .9,
          duration: 120,
          quality: .95,
          timestamp: DateTime.utc(2026),
        );
    expect(
      (await container.read(neuralHistoryStoreProvider).loadNeuralHistory())
          .single
          .reasoning,
      'A_SECRET_NEURAL_REASONING',
    );
    expect((await _readPrediction(container, 'shared-task')).outcome,
        'Likely Success');
    expect(await _readInsight(container),
        'You perform best with your current rhythm.');

    container.read(_scopeProvider.notifier).setSignedOut();
    expect(await container.read(neuralHistoryStoreProvider).loadNeuralHistory(),
        isEmpty);
    expect((await _readPrediction(container, 'shared-task')).sampleSize, 0);
    expect(await _readInsight(container), 'No data yet.');

    container.read(_scopeProvider.notifier).setAuthenticated('B');
    await container.read(aiControllerProvider).appendNeuralDumpEntry(
          task: 'shared-task',
          reasoning: 'B_SECRET_NEURAL_REASONING',
          confidence: .1,
          duration: 30,
          quality: .1,
          timestamp: DateTime.utc(2026, 1, 2),
        );
    final bPrediction = await _readPrediction(container, 'shared-task');
    expect(bPrediction.outcome, 'Risk of Failure');
    expect(bPrediction.signals, contains('mean-quality:0.10'));
    expect(await _readInsight(container),
        'Your sessions are short. Try increasing duration.');
    expect(
      (await container.read(neuralHistoryStoreProvider).loadNeuralHistory())
          .single
          .reasoning,
      'B_SECRET_NEURAL_REASONING',
    );

    container.read(_scopeProvider.notifier).setAuthenticated('A');
    final aPrediction = await _readPrediction(container, 'shared-task');
    expect(aPrediction.outcome, 'Likely Success');
    expect(aPrediction.signals, contains('mean-quality:0.95'));
    expect(await _readInsight(container),
        'You perform best with your current rhythm.');
    expect(
      (await container.read(neuralHistoryStoreProvider).loadNeuralHistory())
          .single
          .reasoning,
      'A_SECRET_NEURAL_REASONING',
    );
  });

  test('real task completion producer writes only the active account history',
      () async {
    final ControllableSecureStoreBackend backend =
        ControllableSecureStoreBackend();
    final SecureStore secureStore = SecureStore(backend: backend);

    await _completeTaskForAccount(
      accountId: 'A',
      taskId: 'same-logical-task',
      title: 'shared-task',
      secureStore: secureStore,
    );
    final NeuralHistoryStore aStore = _store('A', secureStore);
    expect((await aStore.loadNeuralHistory()).single.task, 'shared-task');
    expect((await aStore.loadNeuralHistory()).single.reasoning,
        'Recorded from a completed task.');

    expect(await _store('B', secureStore).loadNeuralHistory(), isEmpty);
    await _completeTaskForAccount(
      accountId: 'B',
      taskId: 'same-logical-task',
      title: 'shared-task',
      secureStore: secureStore,
    );
    expect((await _store('B', secureStore).loadNeuralHistory()).single.task,
        'shared-task');
    expect((await aStore.loadNeuralHistory()).single.task, 'shared-task');
    expect(aStore.storageKey, isNot(_store('B', secureStore).storageKey));
  });

  test('real trajectory follows the current scoped neural prediction', () async {
    final ControllableSecureStoreBackend backend = ControllableSecureStoreBackend();
    final SecureStore secureStore = SecureStore(backend: backend);
    final ProviderContainer container = _trajectoryContainer(secureStore);
    addTearDown(container.dispose);
    final NeuralHistoryStore a = _store('A', secureStore);
    final NeuralHistoryStore b = _store('B', secureStore);
    final NeuralHistoryStore c = _store('C', secureStore);
    await a.appendNeuralEntry(_entryFor('shared-task', .95, 'A_SECRET'));
    await b.appendNeuralEntry(_entryFor('shared-task', .10, 'B_SECRET'));
    await c.appendNeuralEntry(_entryFor('shared-task', .80, 'C_SECRET'));

    container.read(_scopeProvider.notifier).setAuthenticated('A');
    final aTrajectory = await _trajectoryFor(container, expectsPrediction: true);
    expect(aTrajectory.predictionOutcome, 'Likely Success');
    expect(aTrajectory.energy, .9);
    expect(aTrajectory.completedTasks, 5);
    expect(aTrajectory.level, 4);
    container.read(_scopeProvider.notifier).setSignedOut();
    expect((await _trajectoryFor(container, expectsPrediction: false)).predictionTitle, isNull);
    container.read(_scopeProvider.notifier).setAuthenticated('B');
    final bTrajectory = await _trajectoryFor(container, expectsPrediction: true);
    expect(bTrajectory.predictionTitle, 'shared-task');
    expect(bTrajectory.predictionOutcome, 'Risk of Failure');
    expect(bTrajectory.predictionExplanation, isNot(contains('A_')));
    expect(bTrajectory.energy, .4);
    expect(bTrajectory.completedTasks, 2);
    expect(bTrajectory.level, 2);
    container.read(_scopeProvider.notifier).setSignedOut();
    container.read(_scopeProvider.notifier).setAuthenticated('A');
    expect((await _trajectoryFor(container, expectsPrediction: true)).predictionOutcome, 'Likely Success');
    container.read(_scopeProvider.notifier).setSignedOut();
    container.read(_scopeProvider.notifier).setAuthenticated('C');
    final cTrajectory = await _trajectoryFor(container, expectsPrediction: true);
    expect(cTrajectory.predictionOutcome, 'Likely Success');
    expect(cTrajectory.predictionTitle, 'shared-task');
    expect(cTrajectory.energy, .6);
    expect(cTrajectory.completedTasks, 7);
    expect(cTrajectory.level, 6);
  });
}

final NotifierProvider<_ScopeNotifier, AccountStorageScope> _scopeProvider =
    NotifierProvider<_ScopeNotifier, AccountStorageScope>(_ScopeNotifier.new);

class _ScopeNotifier extends Notifier<AccountStorageScope> {
  @override
  AccountStorageScope build() => const AccountStorageScope.signedOut();

  void setAuthenticated(String accountId) {
    state = AccountStorageScope.authenticated(accountId);
  }

  void setSignedOut() => state = const AccountStorageScope.signedOut();
}

ProviderContainer _container(
  SecureStore secureStore, {
  ITaskRepository? taskRepository,
}) {
  return ProviderContainer(
    overrides: [
      accountStorageScopeProvider.overrideWith(
        (Ref ref) => ref.watch(_scopeProvider),
      ),
      secureStoreProvider.overrideWithValue(secureStore),
      if (taskRepository != null) ...[
        domainTaskRepositoryProvider.overrideWithValue(taskRepository),
        completeTaskUseCaseProvider.overrideWithValue(CompleteTask(taskRepository)),
      ],
    ],
  );
}

Future<void> _completeTaskForAccount({
  required String accountId,
  required String taskId,
  required String title,
  required SecureStore secureStore,
}) async {
  final _TaskRepository repository = _TaskRepository(
    TaskEntity(
      id: taskId,
      title: title,
      createdAt: DateTime.utc(2026),
      priority: 2,
      difficulty: 2,
      energyRequired: 2,
    ),
  );
  final ProviderContainer container = _container(
    secureStore,
    taskRepository: repository,
  );
  container.read(_scopeProvider.notifier).setAuthenticated(accountId);
  try {
    await container.read(taskActionsProvider).completeTask(
          taskId,
          notify: false,
          actionSource: 'neural_history_test',
        );
    await Future<void>.delayed(const Duration(milliseconds: 50));
  } finally {
    container.dispose();
  }
}

Future<Prediction> _readPrediction(ProviderContainer container, String title) {
  return container.read(predictionProvider(title).future);
}

Future<String> _readInsight(ProviderContainer container) {
  return container.read(patternInsightProvider.future);
}

ProviderContainer _trajectoryContainer(SecureStore secureStore) {
  return ProviderContainer(overrides: [
    accountStorageScopeProvider.overrideWith((Ref ref) => ref.watch(_scopeProvider)),
    secureStoreProvider.overrideWithValue(secureStore),
    tasksProvider.overrideWith((Ref ref) async {
      final scope = ref.watch(_scopeProvider);
      if (!scope.isAuthenticated) return const <Task>[];
      return const <Task>[Task(id: 'same-task', title: 'shared-task', priority: 1, difficulty: 1, energyRequired: 1)];
    }),
    profileProvider.overrideWith(_TrajectoryProfile.new),
    learningProvider.overrideWith(_TrajectoryLearning.new),
    learningMetricsProvider.overrideWith((Ref ref) => _metricsFor(ref.watch(_scopeProvider))),
    siStateProvider.overrideWith(_TrajectorySiState.new),
    executionSignalsProvider.overrideWith((Ref ref) => const ExecutionSignals(createdToday: 0, completedToday: 1, skippedToday: 0, delayedToday: 0, created7d: 0, completed7d: 1, skipped7d: 0, delayed7d: 0)),
  ]);
}

Future<TrajectorySummaryView> _trajectoryFor(
  ProviderContainer container, {
  required bool expectsPrediction,
}) async {
  final Completer<TrajectorySummaryView> result = Completer<TrajectorySummaryView>();
  late ProviderSubscription<TrajectorySummaryView> subscription;
  subscription = container.listen(trajectorySummaryProvider, (_, TrajectorySummaryView next) {
    if ((expectsPrediction ? next.hasPrediction : next.predictionTitle == null) &&
        !result.isCompleted) {
      result.complete(next);
    }
  }, fireImmediately: true);
  try {
    return await result.future.timeout(const Duration(seconds: 3));
  } finally {
    subscription.close();
  }
}

NeuralHistoryStore _store(String accountId, SecureStore secureStore) {
  return NeuralHistoryStore(
    scope: AccountStorageScope.authenticated(accountId),
    secureStore: secureStore,
  );
}

class _TaskRepository implements ITaskRepository {
  _TaskRepository(this._task);

  TaskEntity _task;

  @override
  Future<void> deleteTask(String id) async {}

  @override
  Future<List<TaskEntity>> getAllTasks() async => <TaskEntity>[_task];

  @override
  Future<TaskEntity?> getTaskById(String id) async => id == _task.id ? _task : null;

  @override
  Future<void> saveTask(TaskEntity task) async => _task = task;
}

class _TrajectoryProfile extends ProfileController {
  @override
  ProfileState build() {
    final scope = ref.watch(_scopeProvider);
    return ProfileState(name: scope.isAuthenticated ? '${scope.rawUserId}_PROFILE' : 'signed_out', level: switch (scope.rawUserId) { 'A' => 4, 'B' => 2, 'C' => 6, _ => 1 }, profileReady: scope.isAuthenticated);
  }
}

class _TrajectoryLearning extends LearningController {
  @override
  LearningState build() => LearningState(completed: switch (ref.watch(_scopeProvider).rawUserId) { 'A' => 5, 'B' => 2, 'C' => 7, _ => 0 });
}

class _TrajectorySiState extends SIStateController {
  @override
  SIState build() => SIState(energy: switch (ref.watch(_scopeProvider).rawUserId) { 'A' => .9, 'B' => .4, 'C' => .6, _ => .5 }, fatigue: .2, completedToday: ref.watch(_scopeProvider).isAuthenticated ? 1 : 0);
}

LearningMetrics _metricsFor(AccountStorageScope scope) => switch (scope.rawUserId) { 'A' => const LearningMetrics(completionRate: .9, momentum: .8, adaptability: .7), 'B' => const LearningMetrics(completionRate: .3, momentum: .2, adaptability: .4), 'C' => const LearningMetrics(completionRate: .8, momentum: .6, adaptability: .5), _ => const LearningMetrics(completionRate: 0, momentum: 0, adaptability: 0) };

NeuralEntry _entryFor(String task, double quality, String reasoning) => NeuralEntry(task: task, reasoning: reasoning, confidence: quality, duration: 90, quality: quality, timestamp: DateTime.utc(2026));
