import 'dart:async';

import 'package:fantastic_guacamole/core/eventing/domain_event.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/domain/entities/si_decision_entity.dart';
import 'package:fantastic_guacamole/domain/entities/si_state_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_si_repository.dart';
import 'package:fantastic_guacamole/domain/policies/completion_side_effect_policy.dart';
import 'package:fantastic_guacamole/domain/usecases/complete_task.dart';
import 'package:fantastic_guacamole/domain/usecases/create_task.dart';
import 'package:fantastic_guacamole/domain/usecases/delete_task.dart';
import 'package:fantastic_guacamole/domain/usecases/generate_si_decision.dart';
import 'package:fantastic_guacamole/domain/usecases/update_task.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/auth_session_boundary_provider.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/event_bus_provider.dart';
import 'package:fantastic_guacamole/state/providers/optimization_provider.dart';
import 'package:fantastic_guacamole/state/providers/task_occurrence_provider.dart';
import 'package:fantastic_guacamole/state/providers/task_provider.dart';
import 'package:fantastic_guacamole/system/analytics/local_metrics_accumulator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final bool deleting in <bool>[false, true]) {
    for (final String transition in <String>['switch', 'return', 'reset']) {
      test(
        '${deleting ? 'delete' : 'update'} ignores an old lookup after $transition',
        () async {
          final _Harness harness = _Harness();
          addTearDown(harness.dispose);
          harness.accountA.lookup = Completer<TaskEntity?>();
          final Future<void> action = deleting
              ? harness.actions.deleteTask('shared-id')
              : harness.actions.updateTask(
                  id: 'shared-id',
                  title: 'Changed by A',
                );
          await harness.accountA.lookupStarted.future;

          if (transition != 'reset') harness.signIn('account-b');
          if (transition != 'switch') harness.signIn('account-a');
          harness.accountA.lookup!.complete(harness.accountA.task);
          await action;

          expect(harness.accountA.task?.title, 'Private A task');
          expect(harness.accountB.task?.title, 'Private B task');
          expect(harness.accountA.mutations, 0);
          expect(harness.accountB.mutations, 0);
          expect(harness.events, isEmpty);
        },
      );
    }
  }

  test('create does not publish old-account side effects after save', () async {
    final _Harness harness = _Harness();
    addTearDown(harness.dispose);
    harness.accountA.saveGate = Completer<void>();
    final Future<void> action = harness.actions.createTask(
      harness.accountA.task!,
    );
    await harness.accountA.saveStarted.future;

    harness.signIn('account-b');
    harness.accountA.saveGate!.complete();
    await action;

    expect(harness.metrics.created, 0);
    expect(harness.events, isEmpty);
    expect(harness.accountB.mutations, 0);
  });

  test(
    'create does not restore a cleared task after planner preparation',
    () async {
      final _Harness harness = _Harness();
      addTearDown(harness.dispose);
      final _DelayedSiDecision decision = _DelayedSiDecision();
      harness.creationDecision = decision;
      final Future<void> action = harness.actions.createTask(
        harness.accountA.task!,
      );
      await decision.started.future;

      harness.signIn('account-a');
      harness.accountA.task = null;
      decision.result.complete(const SiDecisionEntity(rationale: 'Ready'));
      await action;

      expect(harness.accountA.task, isNull);
      expect(harness.accountA.mutations, 0);
      expect(harness.metrics.created, 0);
      expect(harness.events, isEmpty);
    },
  );

  test('create keeps planner preparation within the current session', () async {
    final _Harness harness = _Harness();
    addTearDown(harness.dispose);
    final _DelayedSiDecision decision = _DelayedSiDecision();
    harness.creationDecision = decision;
    final Future<void> action = harness.actions.createTask(
      harness.accountA.task!.copyWith(title: '  Prepared task  ', priority: 5),
    );
    await decision.started.future;
    decision.result.complete(
      const SiDecisionEntity(rationale: 'Simplify', shouldSimplify: true),
    );
    await action;

    expect(harness.accountA.task?.title, 'Prepared task');
    expect(harness.accountA.task?.priority, 1);
    expect(harness.accountA.mutations, 1);
    expect(harness.metrics.created, 1);
  });

  test(
    'complete does not publish old-account rewards after mutation',
    () async {
      final _Harness harness = _Harness();
      addTearDown(harness.dispose);
      final Completer<Object?> mutation = Completer<Object?>();
      final Completer<void> started = Completer<void>();
      harness.durableMutation = (_) {
        started.complete();
        return mutation.future;
      };
      await harness.container.read(tasksProvider.future);
      final Future<void> action = harness.actions.completeTask('shared-id');
      await started.future;

      harness.signIn('account-b');
      mutation.complete(CompletionMutationOutcome.applied);
      await action;

      expect(harness.metrics.completed, 0);
      expect(harness.events, isEmpty);
      expect(harness.accountB.mutations, 0);
    },
  );

  test('skip does not use the next account after task loading', () async {
    final _Harness harness = _Harness(blockCoordinator: true);
    addTearDown(harness.dispose);
    final Completer<List<Task>> loading = Completer<List<Task>>();
    harness.tasksFuture = loading.future;
    final Future<void> action = harness.actions.skipTask('shared-id');
    harness.signIn('account-b');
    loading.complete(<Task>[Task.fromEntity(harness.accountA.task!)]);
    await action;

    expect(harness.coordinatorReads, 0);
    expect(harness.events, isEmpty);
  });

  test('disposed action does not resume a pending lookup', () async {
    final _Harness harness = _Harness();
    harness.accountA.lookup = Completer<TaskEntity?>();
    final Future<void> action = harness.actions.updateTask(
      id: 'shared-id',
      title: 'Changed after dispose',
    );
    await harness.accountA.lookupStarted.future;
    harness.dispose();
    harness.accountA.lookup!.complete(harness.accountA.task);
    await action;
    expect(harness.accountA.mutations, 0);
  });

  for (final bool switchAccount in <bool>[true, false]) {
    test(
      'completion lookup failure ${switchAccount ? 'is ignored after a switch' : 'is reported in the same account'}',
      () async {
        final _Harness harness = _Harness();
        addTearDown(harness.dispose);
        harness.tasksFuture = Future<List<Task>>.value(const <Task>[]);
        harness.durableMutation = (_) async =>
            CompletionMutationOutcome.applied;
        harness.accountA.lookup = Completer<TaskEntity?>();
        await harness.container.read(tasksProvider.future);
        final Future<void> action = harness.actions.completeTask('shared-id');
        await harness.accountA.lookupStarted.future;
        final StateError failure = StateError('Account storage closed');

        if (switchAccount) {
          harness.signIn('account-b');
          await action;
          harness.accountA.lookup!.completeError(failure);
          await Future<void>.delayed(Duration.zero);
        } else {
          final Future<void> expectation = expectLater(
            action,
            throwsA(same(failure)),
          );
          harness.accountA.lookup!.completeError(failure);
          await expectation;
        }
        expect(harness.events, isEmpty);
      },
    );
  }
}

class _Harness {
  _Harness({this.blockCoordinator = false}) {
    container = ProviderContainer(overrides: overrides);
    signIn('account-a');
    subscription = container
        .read(eventBusProvider)
        .on<TaskLifecycleEvent>()
        .listen(events.add);
  }

  final _TaskRepository accountA = _TaskRepository('Private A task');
  final _TaskRepository accountB = _TaskRepository('Private B task');
  final _Metrics metrics = _Metrics();
  final bool blockCoordinator;
  int coordinatorReads = 0;
  DurableCompleteMutation? durableMutation;
  GenerateSiDecision? creationDecision;
  Future<List<Task>>? tasksFuture;
  final List<TaskLifecycleEvent> events = <TaskLifecycleEvent>[];
  late final ProviderContainer container;
  late final StreamSubscription<TaskLifecycleEvent> subscription;

  List<Override> get overrides => [
    accountStorageScopeProvider.overrideWith((Ref ref) {
      final AuthSessionBoundary boundary = ref.watch(
        authSessionBoundaryProvider,
      );
      if (!boundary.isStorageReady) return const AccountStorageScope.unsafe();
      return AccountStorageScope.authenticated(boundary.userId!);
    }),
    domainTaskRepositoryProvider.overrideWith((Ref ref) {
      return ref.watch(accountStorageScopeProvider).rawUserId == 'account-a'
          ? accountA
          : accountB;
    }),
    updateTaskUseCaseProvider.overrideWith(
      (Ref ref) => UpdateTask(ref.watch(domainTaskRepositoryProvider)),
    ),
    deleteTaskUseCaseProvider.overrideWith(
      (Ref ref) => DeleteTask(ref.watch(domainTaskRepositoryProvider)),
    ),
    createTaskUseCaseProvider.overrideWith(
      (Ref ref) => CreateTask(
        ref.watch(domainTaskRepositoryProvider),
        generateSiDecision: creationDecision,
      ),
    ),
    completeTaskUseCaseProvider.overrideWith(
      (Ref ref) => CompleteTask(
        ref.watch(domainTaskRepositoryProvider),
        durableMutation: durableMutation,
      ),
    ),
    if (blockCoordinator)
      taskOccurrenceCoordinatorProvider.overrideWith((Ref ref) {
        coordinatorReads++;
        throw StateError('Unexpected mutation in the new account');
      }),
    localMetricsAccumulatorProvider.overrideWithValue(metrics),
    tasksProvider.overrideWith((Ref ref) async {
      if (tasksFuture != null) return tasksFuture!;
      return (await ref.watch(domainTaskRepositoryProvider).getAllTasks())
          .map(Task.fromEntity)
          .toList();
    }),
  ];

  TaskActions get actions => container.read(taskActionsProvider);

  void signIn(String account) {
    final AuthSessionBoundaryNotifier boundary = container.read(
      authSessionBoundaryProvider.notifier,
    );
    final int generation = boundary.begin(
      userId: account,
      isTransitioning: true,
    );
    boundary.complete(generation);
  }

  void dispose() {
    unawaited(subscription.cancel());
    container.dispose();
  }
}

class _TaskRepository implements ITaskRepository {
  _TaskRepository(String title)
    : task = TaskEntity(
        id: 'shared-id',
        title: title,
        createdAt: DateTime.utc(2026, 9, 5),
      );

  TaskEntity? task;
  int mutations = 0;
  Completer<TaskEntity?>? lookup;
  final Completer<void> lookupStarted = Completer<void>();
  Completer<void>? saveGate;
  final Completer<void> saveStarted = Completer<void>();

  @override
  Future<TaskEntity?> getTaskById(String id) {
    if (!lookupStarted.isCompleted) lookupStarted.complete();
    return lookup?.future ?? Future<TaskEntity?>.value(task);
  }

  @override
  Future<List<TaskEntity>> getAllTasks() async => <TaskEntity>[?task];

  @override
  Future<void> saveTask(TaskEntity value) async {
    if (!saveStarted.isCompleted) saveStarted.complete();
    if (saveGate != null) await saveGate!.future;
    mutations++;
    task = value;
  }

  @override
  Future<void> deleteTask(String id) async {
    mutations++;
    task = null;
  }
}

class _Metrics extends LocalMetricsAccumulator {
  int created = 0;
  int completed = 0;

  @override
  Future<void> recordTaskCreated() async => created++;

  @override
  Future<void> recordTaskCompleted() async => completed++;
}

class _DelayedSiDecision extends GenerateSiDecision {
  _DelayedSiDecision() : super(_TaskRepository('unused'), _EmptySiRepository());

  final Completer<void> started = Completer<void>();
  final Completer<SiDecisionEntity> result = Completer<SiDecisionEntity>();

  @override
  Future<SiDecisionEntity> call([String input = '']) {
    started.complete();
    return result.future;
  }
}

class _EmptySiRepository implements ISiRepository {
  @override
  Future<SiStateEntity?> getCurrentState() async => null;

  @override
  Future<void> saveState(SiStateEntity state) async {}
}
