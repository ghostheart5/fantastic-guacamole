import 'dart:async';
import 'dart:convert';

import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/repositories/milestone_repository.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/milestone_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_milestone_repository.dart';
import 'package:fantastic_guacamole/domain/usecases/milestone_usecases.dart';
import 'package:fantastic_guacamole/domain/trajectory/trajectory_consequence_contract.dart';
import 'package:fantastic_guacamole/state/models/trajectory_summary_view.dart';
import 'package:fantastic_guacamole/state/controllers/prediction_controller.dart';
import 'package:fantastic_guacamole/state/providers/account_scoped_store_provider.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/advisor_provider.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/goals_provider.dart';
import 'package:fantastic_guacamole/state/providers/logs_provider.dart';
import 'package:fantastic_guacamole/state/providers/milestones_provider.dart';
import 'package:fantastic_guacamole/state/providers/task_provider.dart';
import 'package:fantastic_guacamole/state/providers/timeline_provider.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_provider.dart';
import 'package:fantastic_guacamole/state/state/logs_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ProviderContainer fixture({
    FutureOr<List<Task>> Function(Ref)? tasks,
    AsyncValue<List<GoalEntity>> goals = const AsyncData([]),
    LogsState logs = const LogsState(entries: [], isLoading: false),
    TrajectorySourceState trajectory = TrajectorySourceState.ready,
    bool corruptTimeline = false,
    IMilestoneRepository? milestoneRepository,
    SecureStore? predictionStore,
  }) {
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        accountStorageScopeProvider.overrideWithValue(
          AccountStorageScope.authenticated('review-health-test'),
        ),
        tasksProvider.overrideWith(tasks ?? (_) => [_task('open')]),
        goalsReadProvider.overrideWithValue(goals),
        logsProvider.overrideWith(() => _Logs(logs)),
        if (milestoneRepository == null)
          milestonesProvider.overrideWith(_Milestones.new)
        else
          domainMilestoneRepositoryProvider.overrideWithValue(
            milestoneRepository,
          ),
        timelinePersistenceCorruptedProvider.overrideWithValue(corruptTimeline),
        if (predictionStore == null)
          trajectorySummaryProvider.overrideWithValue(_trajectory(trajectory))
        else ...[
          accountSecureStoreProvider.overrideWithValue(predictionStore),
          trajectorySummaryProvider.overrideWith((ref) {
            // Same predictor dependency as the real Trajectory projection;
            // leave the production predictor and its cached failure intact.
            final prediction = ref.watch(predictionProvider('open'));
            return _trajectory(
              prediction.hasValue
                  ? TrajectorySourceState.ready
                  : TrajectorySourceState.partial,
            );
          }),
        ],
        timelineHealthScoreProvider.overrideWithValue(100),
        timelineRiskScoreProvider.overrideWithValue(0),
        timelineOverdueProvider.overrideWithValue([]),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<ProgressionReview> settled(ProviderContainer container) async {
    try {
      await container.read(tasksProvider.future);
    } catch (_) {
      // The provider must retain the failure, rather than convert it to [].
    }
    try {
      await container.read(milestonesProvider.future);
    } catch (_) {
      // The real repository's decode failure must reach review availability.
    }
    return container.read(progressionReviewProvider.future);
  }

  for (final source in ['tasks', 'goals', 'logs', 'trajectory', 'timeline']) {
    test(
      '$source read failure cannot produce a healthy workload review',
      () async {
        final container = fixture(
          tasks: source == 'tasks'
              ? (_) => throw StateError('read failed')
              : null,
          goals: source == 'goals'
              ? AsyncError(StateError('goal read failed'), StackTrace.current)
              : const AsyncData([]),
          logs: LogsState(
            entries: [],
            isLoading: false,
            error: source == 'logs' ? 'read failed' : null,
          ),
          trajectory: source == 'trajectory'
              ? TrajectorySourceState.error
              : TrajectorySourceState.ready,
          corruptTimeline: source == 'timeline',
        );
        final review = await settled(container);
        expect(review.status, ProgressionReviewStatus.unavailable);
        expect(review.canAct, isFalse);
        expect(review.text, contains('unavailable'));
        expect(review.text, isNot(contains('Pressure is manageable')));
        expect(review.text, isNot(contains('Active workload: 0 tasks')));
        expect(await container.read(weeklySummaryProvider.future), review.text);
      },
    );
  }

  test(
    'loading evidence stays unrated and updates when the read finishes',
    () async {
      final pending = Completer<List<Task>>();
      final container = fixture(tasks: (_) => pending.future);
      final subscription = container.listen(
        progressionReviewProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      await container.read(milestonesProvider.future);
      final loading = await container.read(progressionReviewProvider.future);
      expect(loading.status, ProgressionReviewStatus.loading);
      expect(loading.canAct, isFalse);
      expect(loading.text, isNot(contains('Pressure is manageable')));
      pending.complete([_task('open')]);
      await container.read(tasksProvider.future);
      await container.pump();
      final ready = await container.read(progressionReviewProvider.future);
      expect(ready.status, ProgressionReviewStatus.ready);
      expect(ready.text, contains('Active workload: 1 tasks'));
    },
  );

  test(
    'healthy empty data is a baseline, not a storage error or healthy score',
    () async {
      final review = await settled(fixture(tasks: (_) => []));
      expect(review.status, ProgressionReviewStatus.empty);
      expect(review.canAct, isTrue);
      expect(review.text, contains('No saved planning history yet'));
      expect(review.text, isNot(contains('Timeline integrity is stable')));
    },
  );

  test('completed work is excluded from active workload', () async {
    final review = await settled(
      fixture(tasks: (_) => [_task('open'), _task('done', completed: true)]),
    );
    expect(review.status, ProgressionReviewStatus.ready);
    expect(review.text, contains('Active workload: 1 tasks'));
  });

  final validMilestone = MilestoneEntity(
    id: 'saved',
    title: 'Preserved milestone',
    createdAt: DateTime.utc(2026, 9, 1),
    updatedAt: DateTime.utc(2026, 9, 2),
  );
  for (final raw in <String>[
    '{not json',
    '{"unexpected":"object"}',
    jsonEncode([validMilestone.toJson(), 42]),
    jsonEncode([validMilestone.toJson(), <String, dynamic>{}]),
  ]) {
    test(
      'real malformed/partial milestone storage remains unrated: $raw',
      () async {
        final store = SecureStore(backend: InMemorySecureStoreBackend());
        await store.writeString(MilestoneRepository.storageKey, raw);
        final repository = MilestoneRepository(store);
        final container = fixture(milestoneRepository: repository);
        final review = await settled(container);
        expect(container.read(milestonesProvider).hasError, isTrue);
        expect(review.status, ProgressionReviewStatus.unavailable);
        expect(review.text, isNot(contains('Milestones are on-track')));
        expect(await store.readString(MilestoneRepository.storageKey), raw);
        await expectLater(
          CreateMilestone(
            repository,
          ).call(title: 'Must not overwrite evidence'),
          throwsFormatException,
        );
        expect(await store.readString(MilestoneRepository.storageKey), raw);

        // A repaired store can be read again; no poisoned error cache or writes
        // from the failed attempt may replace the recovered collection.
        await store.writeString(
          MilestoneRepository.storageKey,
          jsonEncode([validMilestone.toJson()]),
        );
        container.invalidate(milestonesProvider);
        await container.pump();
        final recovered = await settled(container);
        expect(recovered.status, ProgressionReviewStatus.ready);
        expect((await repository.getMilestones()).single.id, 'saved');
      },
    );
  }

  testWidgets('review retry refreshes a failed cached prediction read', (
    tester,
  ) async {
    final backend = _RecoverablePredictionBackend();
    final container = fixture(predictionStore: SecureStore(backend: backend));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, child) {
              final review = ref.watch(progressionReviewProvider);
              return Column(
                children: [
                  Text(review.asData?.value.status.name ?? 'pending'),
                  FilledButton(
                    onPressed: () => retryProgressionReview(ref),
                    child: const Text('Retry'),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('unavailable'), findsOneWidget);
    expect(container.read(predictionProvider('open')).hasError, isTrue);
    final int readsBeforeRecovery = backend.reads;
    backend.fail = false;
    await tester.tap(find.text('Retry'));
    for (int i = 0; i < 5; i++) {
      await tester.pump();
    }
    expect(find.text('ready'), findsOneWidget);
    expect(backend.reads, greaterThan(readsBeforeRecovery));
    expect(container.read(predictionProvider('open')).hasError, isFalse);
    expect(tester.takeException(), isNull);
  });
}

Task _task(String id, {bool completed = false}) => Task(
  id: id,
  title: id,
  priority: 2,
  difficulty: 2,
  energyRequired: 2,
  isCompleted: completed,
);

class _Logs extends LogsController {
  _Logs(this.saved);
  final LogsState saved;
  @override
  LogsState build() => saved;
}

class _Milestones extends MilestonesNotifier {
  @override
  Future<List<MilestoneEntity>> build() async => [];
}

class _RecoverablePredictionBackend extends InMemorySecureStoreBackend {
  bool fail = true;
  int reads = 0;

  @override
  Future<String?> read({required String key}) async {
    reads++;
    if (fail) throw StateError('Synthetic storage read failure');
    return super.read(key: key);
  }
}

TrajectorySummaryView _trajectory(TrajectorySourceState state) =>
    TrajectorySummaryView(
      pendingTasks: 1,
      completedTasks: 0,
      completedToday: 0,
      level: 1,
      streak: 0,
      energy: .5,
      momentum: 0,
      adaptability: 0,
      lastCompletionXp: 0,
      lastCompletionQuality: 0,
      pressureIndex: 18,
      behaviorDivergence: 0,
      alert: '',
      predictionTitle: null,
      predictionOutcome: null,
      predictionProbability: null,
      predictionExplanation: null,
      sourceState: state,
    );
