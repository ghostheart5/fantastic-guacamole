import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/domain/entities/creator_handshake.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
import 'package:fantastic_guacamole/tutorial/adaptive_guidance.dart';
import 'package:fantastic_guacamole/app/router/route_paths.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/daily_decision_intelligence_provider.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('incomplete core milestones suppress automatic interventions', () {
    final DateTime observedAt = DateTime.utc(2026, 8, 18);
    const AdaptiveGuidanceState beforeFirstValue = AdaptiveGuidanceState(
      milestones: <GuidanceMilestone, DateTime>{},
      counts: <GuidanceMilestone, int>{},
      skippedLessons: <GuidanceLessonId>{},
      completedLessons: <GuidanceLessonId>{},
    );
    final AdaptiveGuidanceState incomplete = AdaptiveGuidanceState(
      milestones: <GuidanceMilestone, DateTime>{
        GuidanceMilestone.firstItem: observedAt,
      },
      counts: const <GuidanceMilestone, int>{},
      skippedLessons: const <GuidanceLessonId>{},
      completedLessons: const <GuidanceLessonId>{
        GuidanceLessonId.createFirstItem,
      },
    );

    expect(
      beforeFirstValue.nextIntervention(
        currentRoute: RoutePaths.nexus,
        decision: _decision,
        now: observedAt,
      ),
      isNull,
    );
    expect(incomplete.coreComplete, isFalse);
    expect(
      incomplete.nextIntervention(
        currentRoute: RoutePaths.nexus,
        decision: _decision,
        now: observedAt.add(const Duration(days: 2)),
      ),
      isNull,
    );

    final AdaptiveGuidanceState complete = AdaptiveGuidanceState(
      milestones: <GuidanceMilestone, DateTime>{
        GuidanceMilestone.firstItem: observedAt,
        GuidanceMilestone.firstSchedule: observedAt,
        GuidanceMilestone.firstTimelineReview: observedAt,
      },
      counts: const <GuidanceMilestone, int>{},
      skippedLessons: const <GuidanceLessonId>{},
      completedLessons: const <GuidanceLessonId>{
        GuidanceLessonId.createFirstItem,
        GuidanceLessonId.scheduleFirstItem,
        GuidanceLessonId.reviewTimeline,
      },
    );

    expect(complete.coreComplete, isTrue);
    expect(
      complete
          .nextIntervention(
            currentRoute: RoutePaths.nexus,
            decision: _decision,
            now: observedAt.add(const Duration(days: 2)),
          )
          ?.id,
      GuidanceLessonId.nexus,
    );
  });

  test('explicit replay remains available before core completion', () {
    const AdaptiveGuidanceState state = AdaptiveGuidanceState(
      milestones: <GuidanceMilestone, DateTime>{},
      counts: <GuidanceMilestone, int>{},
      skippedLessons: <GuidanceLessonId>{},
      completedLessons: <GuidanceLessonId>{},
      replayLessons: <GuidanceLessonId>{GuidanceLessonId.reviewTimeline},
    );

    expect(
      state
          .nextIntervention(currentRoute: RoutePaths.nexus, decision: _decision)
          ?.id,
      GuidanceLessonId.reviewTimeline,
    );
  });

  test(
    'finishing core setup returns control to Nexus before advanced help',
    () {
      final DateTime observedAt = DateTime.utc(2026, 8, 20, 17);
      final AdaptiveGuidanceState state = AdaptiveGuidanceState(
        milestones: <GuidanceMilestone, DateTime>{
          GuidanceMilestone.firstItem: observedAt,
          GuidanceMilestone.firstSchedule: observedAt,
          GuidanceMilestone.firstTimelineReview: observedAt,
        },
        counts: const <GuidanceMilestone, int>{},
        skippedLessons: const <GuidanceLessonId>{},
        completedLessons: const <GuidanceLessonId>{
          GuidanceLessonId.createFirstItem,
          GuidanceLessonId.scheduleFirstItem,
          GuidanceLessonId.reviewTimeline,
        },
      );

      expect(
        state.nextIntervention(
          currentRoute: RoutePaths.nexus,
          decision: _decision,
          now: observedAt.add(const Duration(minutes: 1)),
        ),
        isNull,
      );
    },
  );

  test('completed and skipped lessons are suppressed', () {
    final DateTime observedAt = DateTime.utc(2026, 8, 18);
    final AdaptiveGuidanceState state = AdaptiveGuidanceState(
      milestones: <GuidanceMilestone, DateTime>{
        GuidanceMilestone.firstItem: observedAt,
        GuidanceMilestone.firstSchedule: observedAt,
        GuidanceMilestone.firstTimelineReview: observedAt,
      },
      counts: const <GuidanceMilestone, int>{},
      skippedLessons: const <GuidanceLessonId>{GuidanceLessonId.nexus},
      completedLessons: const <GuidanceLessonId>{
        GuidanceLessonId.createFirstItem,
        GuidanceLessonId.scheduleFirstItem,
        GuidanceLessonId.reviewTimeline,
        GuidanceLessonId.smartPlanner,
      },
    );

    expect(
      state
          .nextIntervention(
            currentRoute: RoutePaths.timeline,
            decision: _decision,
          )
          ?.id,
      GuidanceLessonId.timelineExecution,
    );
  });

  test('repeated deferral selects a correction intervention', () {
    final DateTime observedAt = DateTime.utc(2026, 8, 18);
    final AdaptiveGuidanceState state = AdaptiveGuidanceState(
      milestones: <GuidanceMilestone, DateTime>{
        GuidanceMilestone.firstItem: observedAt,
        GuidanceMilestone.firstSchedule: observedAt,
        GuidanceMilestone.firstTimelineReview: observedAt,
      },
      counts: const <GuidanceMilestone, int>{
        GuidanceMilestone.firstTaskDeferral: 2,
      },
      skippedLessons: const <GuidanceLessonId>{},
      completedLessons: const <GuidanceLessonId>{
        GuidanceLessonId.createFirstItem,
        GuidanceLessonId.scheduleFirstItem,
        GuidanceLessonId.reviewTimeline,
      },
    );

    expect(
      state
          .nextIntervention(currentRoute: RoutePaths.nexus, decision: _decision)
          ?.id,
      GuidanceLessonId.timelineExecution,
    );
  });

  test('existing tasks repair missing first-run milestones durably', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final _GuidanceTaskRepository repository =
        _GuidanceTaskRepository(<TaskEntity>[
          TaskEntity(
            id: 'existing-scheduled-task',
            title: 'Already on Timeline',
            createdAt: DateTime.utc(2026, 8, 20, 9),
            scheduledFor: DateTime.utc(2026, 8, 20, 10),
          ),
        ]);
    final ProviderContainer first = ProviderContainer(
      overrides: [
        accountStorageScopeProvider.overrideWithValue(
          AccountStorageScope.authenticated('guidance-repair-user'),
        ),
        domainTaskRepositoryProvider.overrideWithValue(repository),
      ],
    );

    final AdaptiveGuidanceState repaired = await first.read(
      adaptiveGuidanceProvider.future,
    );
    expect(repaired.has(GuidanceMilestone.firstItem), isTrue);
    expect(repaired.has(GuidanceMilestone.firstSchedule), isTrue);
    first.dispose();

    final ProviderContainer restarted = ProviderContainer(
      overrides: [
        accountStorageScopeProvider.overrideWithValue(
          AccountStorageScope.authenticated('guidance-repair-user'),
        ),
        domainTaskRepositoryProvider.overrideWithValue(
          _GuidanceTaskRepository(const <TaskEntity>[]),
        ),
      ],
    );
    addTearDown(restarted.dispose);
    final AdaptiveGuidanceState persisted = await restarted.read(
      adaptiveGuidanceProvider.future,
    );

    expect(persisted.has(GuidanceMilestone.firstItem), isTrue);
    expect(persisted.has(GuidanceMilestone.firstSchedule), isTrue);
  });

  test(
    'Later is resumable while Skip remains permanent across restart',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final ProviderContainer first = _guidanceContainer(
        'guidance-actions-user',
      );
      await first.read(adaptiveGuidanceProvider.future);
      final AdaptiveGuidanceNotifier notifier = first.read(
        adaptiveGuidanceProvider.notifier,
      );

      await notifier.record(GuidanceMilestone.firstItem);
      await notifier.later(GuidanceLessonId.nexus);
      await notifier.skip(GuidanceLessonId.siConsole);
      first.dispose();

      final ProviderContainer restarted = _guidanceContainer(
        'guidance-actions-user',
      );
      addTearDown(restarted.dispose);
      final AdaptiveGuidanceState persisted = await restarted.read(
        adaptiveGuidanceProvider.future,
      );
      expect(persisted.laterLessons, contains(GuidanceLessonId.nexus));
      expect(persisted.skippedLessons, contains(GuidanceLessonId.siConsole));

      await restarted.read(adaptiveGuidanceProvider.notifier).restartLessons();
      final AdaptiveGuidanceState afterRestart = restarted
          .read(adaptiveGuidanceProvider)
          .requireValue;
      expect(afterRestart.laterLessons, isEmpty);
      expect(afterRestart.skippedLessons, contains(GuidanceLessonId.siConsole));
      expect(afterRestart.has(GuidanceMilestone.firstItem), isTrue);
    },
  );

  test(
    'Replay reopens core guidance without deleting product milestones',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final ProviderContainer first = _guidanceContainer(
        'guidance-replay-user',
      );
      await first.read(adaptiveGuidanceProvider.future);
      final AdaptiveGuidanceNotifier notifier = first.read(
        adaptiveGuidanceProvider.notifier,
      );
      await notifier.record(GuidanceMilestone.firstItem);
      await notifier.record(GuidanceMilestone.firstSchedule);
      await notifier.record(GuidanceMilestone.firstTimelineReview);

      await notifier.replayOnboarding();
      final AdaptiveGuidanceState replaying = first
          .read(adaptiveGuidanceProvider)
          .requireValue;
      expect(replaying.coreComplete, isTrue);
      expect(replaying.replayLessons, _replayableCoreLessonMatcher);
      expect(
        replaying
            .nextIntervention(
              currentRoute: RoutePaths.nexus,
              decision: _decision,
            )
            ?.id,
        GuidanceLessonId.createFirstItem,
      );
      first.dispose();

      final ProviderContainer restarted = _guidanceContainer(
        'guidance-replay-user',
      );
      addTearDown(restarted.dispose);
      final AdaptiveGuidanceState persisted = await restarted.read(
        adaptiveGuidanceProvider.future,
      );
      expect(persisted.coreComplete, isTrue);
      expect(persisted.replayLessons, _replayableCoreLessonMatcher);
    },
  );

  test(
    'Creator receipt task IDs persist until Timeline review succeeds',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final AccountStorageScope scope = AccountStorageScope.authenticated(
        'guidance-receipt-user',
      );
      final ProviderContainer first = _guidanceContainer(
        'guidance-receipt-user',
      );
      await first.read(adaptiveGuidanceProvider.future);
      await first
          .read(adaptiveGuidanceProvider.notifier)
          .recordCreatorHandshakeReceipt(
            _receipt(scope.v2Namespace!, <String>['task-b', 'task-a']),
          );
      first.dispose();

      final ProviderContainer restarted = _guidanceContainer(
        'guidance-receipt-user',
      );
      final AdaptiveGuidanceState persisted = await restarted.read(
        adaptiveGuidanceProvider.future,
      );
      expect(persisted.matchesExpectedFirstRunCreatorTask('task-a'), isTrue);
      expect(persisted.matchesExpectedFirstRunCreatorTask('task-b'), isTrue);
      expect(
        persisted.matchesExpectedFirstRunCreatorTask('other-task'),
        isFalse,
      );

      await restarted
          .read(adaptiveGuidanceProvider.notifier)
          .record(GuidanceMilestone.firstTimelineReview);
      expect(
        restarted
            .read(adaptiveGuidanceProvider)
            .requireValue
            .expectedFirstRunCreatorTaskIds,
        isEmpty,
      );
      restarted.dispose();

      final ProviderContainer verified = _guidanceContainer(
        'guidance-receipt-user',
      );
      addTearDown(verified.dispose);
      expect(
        (await verified.read(
          adaptiveGuidanceProvider.future,
        )).expectedFirstRunCreatorTaskIds,
        isEmpty,
      );
    },
  );

  test(
    'Restart clears pending Creator evidence but preserves milestones',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final AccountStorageScope scope = AccountStorageScope.authenticated(
        'guidance-restart-user',
      );
      final ProviderContainer container = _guidanceContainer(
        'guidance-restart-user',
      );
      addTearDown(container.dispose);
      await container.read(adaptiveGuidanceProvider.future);
      final AdaptiveGuidanceNotifier notifier = container.read(
        adaptiveGuidanceProvider.notifier,
      );
      await notifier.record(GuidanceMilestone.firstItem);
      await notifier.recordCreatorHandshakeReceipt(
        _receipt(scope.v2Namespace!, <String>['expected-task']),
      );

      await notifier.restartLessons();
      final AdaptiveGuidanceState restarted = container
          .read(adaptiveGuidanceProvider)
          .requireValue;
      expect(restarted.expectedFirstRunCreatorTaskIds, isEmpty);
      expect(restarted.has(GuidanceMilestone.firstItem), isTrue);
    },
  );
}

Matcher get _replayableCoreLessonMatcher => containsAll(<GuidanceLessonId>{
  GuidanceLessonId.createFirstItem,
  GuidanceLessonId.scheduleFirstItem,
  GuidanceLessonId.reviewTimeline,
});

ProviderContainer _guidanceContainer(String accountId) {
  return ProviderContainer(
    overrides: [
      accountStorageScopeProvider.overrideWithValue(
        AccountStorageScope.authenticated(accountId),
      ),
      domainTaskRepositoryProvider.overrideWithValue(
        _GuidanceTaskRepository(const <TaskEntity>[]),
      ),
    ],
  );
}

CreatorHandshakeReceipt _receipt(String accountScopeId, List<String> taskIds) {
  final DateTime appliedAt = DateTime.utc(2026, 8, 29, 12);
  return CreatorHandshakeReceipt(
    proposalId: 'proposal-1',
    accountScopeId: accountScopeId,
    confirmationTokenId: 'token-1',
    appliedOperationIds: const <String>['operation-1'],
    taskIds: taskIds,
    appliedAt: appliedAt,
    undoExpiresAt: appliedAt.add(const Duration(minutes: 10)),
    resultingDomainRevision: 'revision-1',
  );
}

class _GuidanceTaskRepository implements ITaskRepository {
  _GuidanceTaskRepository(this.tasks);

  final List<TaskEntity> tasks;

  @override
  Future<void> deleteTask(String id) async {}

  @override
  Future<List<TaskEntity>> getAllTasks() async => tasks;

  @override
  Future<TaskEntity?> getTaskById(String id) async =>
      tasks.where((TaskEntity task) => task.id == id).firstOrNull;

  @override
  Future<void> saveTask(TaskEntity task) async {}
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
