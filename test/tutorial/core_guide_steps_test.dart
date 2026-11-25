import 'package:fantastic_guacamole/app/router/route_paths.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/domain/entities/creator_handshake.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/daily_decision_intelligence_provider.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/tutorial/adaptive_guidance.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// The first-run guide's own steps: "Skip this step", how it ends, and the
// list of task ids it looks for on the schedule.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  group('Skip this step', () {
    test('on the first step moves to the schedule step without a milestone '
        'and survives a reload', () async {
      final ProviderContainer first = _container('step-skip-user');
      await first.read(adaptiveGuidanceProvider.future);
      final AdaptiveGuidanceNotifier notifier = first.read(
        adaptiveGuidanceProvider.notifier,
      );
      await notifier.recordCreatorHandshakeReceipt(
        _receipt('step-skip-user', <String>['saved-task']),
      );

      await notifier.skipCoreStep(GuidanceLessonId.createFirstItem);

      final AdaptiveGuidanceState state = first
          .read(adaptiveGuidanceProvider)
          .requireValue;
      expect(state.activeCoreLesson, GuidanceLessonId.reviewTimeline);
      expect(state.coreGuideStatus, CoreGuideStatus.active);
      // Nothing is recorded as done or dismissed, and no prompt is muted.
      expect(state.milestones, isEmpty);
      expect(state.skippedLessons, isEmpty);
      expect(state.coreComplete, isFalse);
      first.dispose();

      final ProviderContainer reloaded = _container('step-skip-user');
      addTearDown(reloaded.dispose);
      final AdaptiveGuidanceState persisted = await reloaded.read(
        adaptiveGuidanceProvider.future,
      );
      expect(persisted.activeCoreLesson, GuidanceLessonId.reviewTimeline);
      expect(persisted.milestones, isEmpty);
    });

    test('on the last step ends the guide as skipped and clears the task '
        'ids', () async {
      final ProviderContainer first = _container('last-step-user');
      await first.read(adaptiveGuidanceProvider.future);
      final AdaptiveGuidanceNotifier notifier = first.read(
        adaptiveGuidanceProvider.notifier,
      );
      await notifier.recordCreatorHandshakeReceipt(
        _receipt('last-step-user', <String>['saved-task']),
      );
      await notifier.record(GuidanceMilestone.firstItem);
      await notifier.record(GuidanceMilestone.firstSchedule);
      expect(
        first.read(adaptiveGuidanceProvider).requireValue.activeCoreLesson,
        GuidanceLessonId.reviewTimeline,
      );

      await notifier.skipCoreStep(GuidanceLessonId.reviewTimeline);

      final AdaptiveGuidanceState state = first
          .read(adaptiveGuidanceProvider)
          .requireValue;
      expect(state.activeCoreLesson, isNull);
      expect(state.coreGuideStatus, CoreGuideStatus.skipped);
      expect(state.has(GuidanceMilestone.firstTimelineReview), isFalse);
      expect(state.has(GuidanceMilestone.guidanceDismissed), isFalse);
      expect(state.expectedFirstRunCreatorTaskIds, isEmpty);
      // The hint for the screen in view still appears once the core is off.
      expect(
        state
            .nextIntervention(
              currentRoute: RoutePaths.siConsole,
              decision: _decision,
            )
            ?.id,
        GuidanceLessonId.siConsole,
      );
      first.dispose();

      final ProviderContainer reloaded = _container('last-step-user');
      addTearDown(reloaded.dispose);
      final AdaptiveGuidanceState persisted = await reloaded.read(
        adaptiveGuidanceProvider.future,
      );
      expect(persisted.activeCoreLesson, isNull);
      expect(persisted.coreGuideStatus, CoreGuideStatus.skipped);
      expect(persisted.expectedFirstRunCreatorTaskIds, isEmpty);
    });

    test('on the first step with nothing saved ends the guide', () async {
      final ProviderContainer container = _container('nothing-saved-user');
      addTearDown(container.dispose);
      await container.read(adaptiveGuidanceProvider.future);
      await container
          .read(adaptiveGuidanceProvider.notifier)
          .skipCoreStep(GuidanceLessonId.createFirstItem);
      final AdaptiveGuidanceState state = container
          .read(adaptiveGuidanceProvider)
          .requireValue;
      expect(state.activeCoreLesson, isNull);
      expect(state.coreGuideStatus, CoreGuideStatus.skipped);
      expect(state.milestones, isEmpty);
    });

    test('then pausing the next step reports a pause', () async {
      final ProviderContainer container = _container('skip-then-pause');
      addTearDown(container.dispose);
      await container.read(adaptiveGuidanceProvider.future);
      final AdaptiveGuidanceNotifier notifier = container.read(
        adaptiveGuidanceProvider.notifier,
      );
      await notifier.recordCreatorHandshakeReceipt(
        _receipt('skip-then-pause', <String>['saved-task']),
      );
      await notifier.skipCoreStep(GuidanceLessonId.createFirstItem);
      await notifier.later(GuidanceLessonId.reviewTimeline);
      final AdaptiveGuidanceState state = container
          .read(adaptiveGuidanceProvider)
          .requireValue;
      expect(state.activeCoreLesson, isNull);
      expect(state.coreGuideStatus, CoreGuideStatus.paused);
    });

    test('Restart brings skipped steps back', () async {
      final ProviderContainer container = _container('skip-restart');
      addTearDown(container.dispose);
      await container.read(adaptiveGuidanceProvider.future);
      final AdaptiveGuidanceNotifier notifier = container.read(
        adaptiveGuidanceProvider.notifier,
      );
      await notifier.skipCoreStep(GuidanceLessonId.createFirstItem);
      await notifier.restartLessons();
      final AdaptiveGuidanceState state = container
          .read(adaptiveGuidanceProvider)
          .requireValue;
      expect(state.skippedCoreSteps, isEmpty);
      expect(state.activeCoreLesson, GuidanceLessonId.createFirstItem);
    });
  });

  test('a stored skip from an older version keeps the guide off', () async {
    final String prefix =
        'adaptive_guidance_v3.${AccountStorageScope.authenticated('legacy-skip').v2Namespace}';
    SharedPreferences.setMockInitialValues(<String, Object>{
      '$prefix.skip.createFirstItem': true,
      '$prefix.expected_first_run_creator_task_ids': <String>['old-task'],
    });
    final ProviderContainer container = _container('legacy-skip');
    addTearDown(container.dispose);
    final AdaptiveGuidanceState state = await container.read(
      adaptiveGuidanceProvider.future,
    );
    expect(state.activeCoreLesson, isNull);
    expect(state.coreGuideStatus, CoreGuideStatus.skipped);
  });

  group('expected first-run task ids', () {
    for (final String muted in <String>[
      'skipped',
      'paused',
      'paused until reopened',
      'complete',
    ]) {
      test('are not recorded while the guide is $muted', () async {
        final ProviderContainer container = _container('muted-$muted');
        addTearDown(container.dispose);
        await container.read(adaptiveGuidanceProvider.future);
        final AdaptiveGuidanceNotifier notifier = container.read(
          adaptiveGuidanceProvider.notifier,
        );
        switch (muted) {
          case 'skipped':
            await notifier.skipCoreGuide();
          case 'paused':
            await notifier.later(GuidanceLessonId.createFirstItem);
          case 'paused until reopened':
            await notifier.pauseCoreGuideUntilReopened();
          default:
            await notifier.record(GuidanceMilestone.firstItem);
            await notifier.record(GuidanceMilestone.firstSchedule);
            await notifier.record(GuidanceMilestone.firstTimelineReview);
        }
        expect(
          container
              .read(adaptiveGuidanceProvider)
              .requireValue
              .activeCoreLesson,
          isNull,
        );
        for (int i = 0; i < 3; i++) {
          await notifier.recordCreatorHandshakeReceipt(
            _receipt('muted-$muted', <String>['task-$i']),
          );
        }
        expect(
          container
              .read(adaptiveGuidanceProvider)
              .requireValue
              .expectedFirstRunCreatorTaskIds,
          isEmpty,
        );
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getKeys().where(
            (String key) => key.endsWith('expected_first_run_creator_task_ids'),
          ),
          isEmpty,
        );
      });
    }

    test('keep only the newest 20', () async {
      final ProviderContainer first = _container('capped-user');
      await first.read(adaptiveGuidanceProvider.future);
      final AdaptiveGuidanceNotifier notifier = first.read(
        adaptiveGuidanceProvider.notifier,
      );
      for (int i = 0; i < 25; i++) {
        await notifier.recordCreatorHandshakeReceipt(
          _receipt('capped-user', <String>['task-$i']),
        );
      }
      final List<String> newest = <String>[
        for (int i = 5; i < 25; i++) 'task-$i',
      ];
      expect(
        first
            .read(adaptiveGuidanceProvider)
            .requireValue
            .expectedFirstRunCreatorTaskIds
            .toList(),
        newest,
      );
      first.dispose();

      final ProviderContainer reloaded = _container('capped-user');
      addTearDown(reloaded.dispose);
      final AdaptiveGuidanceState persisted = await reloaded.read(
        adaptiveGuidanceProvider.future,
      );
      expect(persisted.expectedFirstRunCreatorTaskIds.toList(), newest);
      expect(persisted.matchesExpectedFirstRunCreatorTask('task-4'), isFalse);
      expect(persisted.matchesExpectedFirstRunCreatorTask('task-24'), isTrue);
    });

    test('an older, longer stored list still loads, capped', () async {
      final String prefix =
          'adaptive_guidance_v3.${AccountStorageScope.authenticated('old-list').v2Namespace}';
      final List<String> stored = <String>[
        for (int i = 10; i < 40; i++) 'old-$i',
      ];
      SharedPreferences.setMockInitialValues(<String, Object>{
        '$prefix.expected_first_run_creator_task_ids': stored,
      });
      final ProviderContainer container = _container('old-list');
      addTearDown(container.dispose);
      final AdaptiveGuidanceState state = await container.read(
        adaptiveGuidanceProvider.future,
      );
      expect(state.expectedFirstRunCreatorTaskIds, hasLength(20));
      expect(state.matchesExpectedFirstRunCreatorTask('old-39'), isTrue);
    });

    test('are cleared when the whole guide is skipped', () async {
      final ProviderContainer first = _container('skip-all-clears');
      await first.read(adaptiveGuidanceProvider.future);
      final AdaptiveGuidanceNotifier notifier = first.read(
        adaptiveGuidanceProvider.notifier,
      );
      await notifier.recordCreatorHandshakeReceipt(
        _receipt('skip-all-clears', <String>['saved-task']),
      );
      await notifier.skipCoreGuide();
      expect(
        first
            .read(adaptiveGuidanceProvider)
            .requireValue
            .expectedFirstRunCreatorTaskIds,
        isEmpty,
      );
      first.dispose();
      final ProviderContainer reloaded = _container('skip-all-clears');
      addTearDown(reloaded.dispose);
      expect(
        (await reloaded.read(
          adaptiveGuidanceProvider.future,
        )).expectedFirstRunCreatorTaskIds,
        isEmpty,
      );
    });
  });

  test('after the guide ends at the schedule, marking a task done is a later '
      'one-time hint on the schedule, not a step', () {
    final DateTime foundAt = DateTime.utc(2026, 11, 1, 9);
    final AdaptiveGuidanceState state = AdaptiveGuidanceState(
      milestones: <GuidanceMilestone, DateTime>{
        GuidanceMilestone.firstItem: foundAt,
        GuidanceMilestone.firstSchedule: foundAt,
        GuidanceMilestone.firstTimelineReview: foundAt,
      },
      counts: const <GuidanceMilestone, int>{},
      skippedLessons: const <GuidanceLessonId>{},
      completedLessons: const <GuidanceLessonId>{},
    );
    expect(state.coreComplete, isTrue);
    expect(state.has(GuidanceMilestone.firstCompletion), isFalse);
    expect(
      state.nextIntervention(
        currentRoute: RoutePaths.timeline,
        decision: _decision,
        now: foundAt.add(const Duration(hours: 1)),
      ),
      isNull,
    );
    final GuidanceLesson? later = state.nextIntervention(
      currentRoute: RoutePaths.timeline,
      decision: _decision,
      now: foundAt.add(const Duration(days: 2)),
    );
    expect(later?.id, GuidanceLessonId.timelineExecution);
    expect(later?.body, contains('Mark it done'));
  });
}

ProviderContainer _container(String accountId) {
  return ProviderContainer(
    overrides: [
      accountStorageScopeProvider.overrideWithValue(
        AccountStorageScope.authenticated(accountId),
      ),
      domainTaskRepositoryProvider.overrideWithValue(_NoTasks()),
    ],
  );
}

CreatorHandshakeReceipt _receipt(String accountId, List<String> taskIds) {
  final DateTime appliedAt = DateTime.utc(2026, 11, 1, 12);
  return CreatorHandshakeReceipt(
    proposalId: 'proposal-${taskIds.join()}',
    accountScopeId: AccountStorageScope.authenticated(accountId).v2Namespace!,
    confirmationTokenId: 'token',
    appliedOperationIds: const <String>['operation'],
    taskIds: taskIds,
    appliedAt: appliedAt,
    undoExpiresAt: appliedAt.add(const Duration(minutes: 10)),
    resultingDomainRevision: 'revision',
  );
}

class _NoTasks implements ITaskRepository {
  @override
  Future<void> deleteTask(String id) async {}

  @override
  Future<List<TaskEntity>> getAllTasks() async => const <TaskEntity>[];

  @override
  Future<TaskEntity?> getTaskById(String id) async => null;

  @override
  Future<void> saveTask(TaskEntity task) async {}
}

const DailyDecisionIntelligence _decision = DailyDecisionIntelligence(
  primaryAction: 'Work on Task A',
  momentum: '60% steady',
  trajectory: 'Stable',
  energy: '70% energy',
  warning: 'Too much is scheduled for Friday.',
  recovery: 'Protect a short recovery window.',
  recommendedAction: 'Work on Task A',
  rationale: 'Task A is the highest feasible item.',
  changeSummary: 'Task A moved up.',
  evidence: <String>['priority=5'],
  confidence: .7,
  observedOutcomes: 1,
);
