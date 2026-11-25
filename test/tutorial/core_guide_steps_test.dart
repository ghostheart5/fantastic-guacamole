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
    // A guide hidden only until the app is reopened still keeps them: see
    // "Today's own Add button during step 1" below.
    for (final String muted in <String>['skipped', 'paused', 'complete']) {
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

  // Today's own "Add a goal, task or habit" button opens the plain form and
  // hides the guide until the app is next opened. A task saved there is
  // still the guide's first task, so the next launch goes on to step 2
  // instead of asking for a first task again.
  group("Today's own Add button during step 1", () {
    Future<AdaptiveGuidanceState> saveWhileHiddenThenReopen(
      String account, {
      required bool dated,
      Future<void> Function(AdaptiveGuidanceNotifier notifier)? before,
    }) async {
      final ProviderContainer first = _container(account);
      await first.read(adaptiveGuidanceProvider.future);
      final AdaptiveGuidanceNotifier notifier = first.read(
        adaptiveGuidanceProvider.notifier,
      );
      await before?.call(notifier);
      await notifier.pauseCoreGuideUntilReopened();
      // What confirming in Add something records, in the same order.
      await notifier.recordCreatorHandshakeReceipt(
        _receipt(account, <String>['saved-task']),
      );
      await notifier.recordIfMissing(GuidanceMilestone.firstItem);
      if (dated) {
        await notifier.recordIfMissing(GuidanceMilestone.firstSchedule);
      }
      // Hidden for the rest of this run.
      expect(
        first.read(adaptiveGuidanceProvider).requireValue.activeCoreLesson,
        isNull,
      );
      first.dispose();

      final ProviderContainer reopened = _container(account);
      addTearDown(reopened.dispose);
      return reopened.read(adaptiveGuidanceProvider.future);
    }

    test('a task saved with a date resumes at step 2', () async {
      final AdaptiveGuidanceState state = await saveWhileHiddenThenReopen(
        'add-button-dated',
        dated: true,
      );
      expect(state.activeCoreLesson, GuidanceLessonId.reviewTimeline);
      expect(state.coreGuideStatus, CoreGuideStatus.active);
      expect(state.matchesExpectedFirstRunCreatorTask('saved-task'), isTrue);
    });

    test(
      'a task saved without a date also resumes at step 2, not step 1',
      () async {
        final AdaptiveGuidanceState state = await saveWhileHiddenThenReopen(
          'add-button-undated',
          dated: false,
        );
        expect(state.activeCoreLesson, GuidanceLessonId.reviewTimeline);
        expect(state.matchesExpectedFirstRunCreatorTask('saved-task'), isTrue);
        expect(state.has(GuidanceMilestone.firstSchedule), isFalse);
      },
    );

    test('a guide skipped before is not brought back', () async {
      final AdaptiveGuidanceState state = await saveWhileHiddenThenReopen(
        'add-button-skipped',
        dated: true,
        before: (AdaptiveGuidanceNotifier notifier) => notifier.skipCoreGuide(),
      );
      expect(state.activeCoreLesson, isNull);
      expect(state.coreGuideStatus, CoreGuideStatus.skipped);
      expect(state.expectedFirstRunCreatorTaskIds, isEmpty);
    });

    test('a guide paused before stays paused', () async {
      final AdaptiveGuidanceState state = await saveWhileHiddenThenReopen(
        'add-button-paused',
        dated: true,
        before: (AdaptiveGuidanceNotifier notifier) =>
            notifier.later(GuidanceLessonId.createFirstItem),
      );
      expect(state.activeCoreLesson, isNull);
      expect(state.coreGuideStatus, CoreGuideStatus.paused);
      expect(state.expectedFirstRunCreatorTaskIds, isEmpty);
    });

    test('with an undated task, Skip this step on step 2 ends the guide for '
        'good, also after a reload', () async {
      await saveWhileHiddenThenReopen('add-button-undated-skip', dated: false);
      final ProviderContainer container = _container('add-button-undated-skip');
      addTearDown(container.dispose);
      await container.read(adaptiveGuidanceProvider.future);
      await container
          .read(adaptiveGuidanceProvider.notifier)
          .skipCoreStep(GuidanceLessonId.reviewTimeline);
      final AdaptiveGuidanceState state = container
          .read(adaptiveGuidanceProvider)
          .requireValue;
      expect(state.activeCoreLesson, isNull);
      expect(state.coreGuideStatus, CoreGuideStatus.skipped);
      expect(state.expectedFirstRunCreatorTaskIds, isEmpty);

      final ProviderContainer reloaded = _container('add-button-undated-skip');
      addTearDown(reloaded.dispose);
      final AdaptiveGuidanceState persisted = await reloaded.read(
        adaptiveGuidanceProvider.future,
      );
      expect(persisted.activeCoreLesson, isNull);
      expect(persisted.coreGuideStatus, CoreGuideStatus.skipped);
    });

    test('"I found my task" ends the guide for good even if the time was not '
        'recorded', () async {
      // firstSchedule is written best-effort after the save; if it is lost
      // the guide still reaches step 2, and finishing it must not bring
      // step 1 back.
      await saveWhileHiddenThenReopen('found-without-time', dated: false);
      final ProviderContainer container = _container('found-without-time');
      addTearDown(container.dispose);
      await container.read(adaptiveGuidanceProvider.future);
      await container
          .read(adaptiveGuidanceProvider.notifier)
          .record(GuidanceMilestone.firstTimelineReview);
      final AdaptiveGuidanceState state = container
          .read(adaptiveGuidanceProvider)
          .requireValue;
      expect(state.activeCoreLesson, isNull);
      expect(state.coreGuideStatus, CoreGuideStatus.complete);
      expect(state.coreComplete, isTrue);
    });
  });

  // A stored skip or pause of the time step alone (older versions wrote one
  // for a single step) keeps the guide off even with a leftover task list.
  for (final String flag in <String>['skip', 'later']) {
    test('a stored $flag of the time step alone, with a leftover task list, '
        'keeps the guide off', () async {
      final String account = 'legacy-$flag-schedule';
      final String prefix =
          'adaptive_guidance_v3.${AccountStorageScope.authenticated(account).v2Namespace}';
      SharedPreferences.setMockInitialValues(<String, Object>{
        '$prefix.$flag.scheduleFirstItem': true,
        '$prefix.firstItem.at': DateTime.utc(2026, 1, 1).millisecondsSinceEpoch,
        '$prefix.firstItem.count': 1,
        '$prefix.expected_first_run_creator_task_ids': <String>['old-task'],
      });
      final ProviderContainer container = _container(account);
      addTearDown(container.dispose);
      final AdaptiveGuidanceState state = await container.read(
        adaptiveGuidanceProvider.future,
      );
      expect(state.activeCoreLesson, isNull);
      expect(
        state.coreGuideStatus,
        flag == 'skip' ? CoreGuideStatus.skipped : CoreGuideStatus.paused,
      );
    });
  }

  group('every stored shape resolves as recorded in the fix report', () {
    final DateTime at = DateTime.utc(2026, 1, 1);
    const GuidanceLessonId create = GuidanceLessonId.createFirstItem;
    const GuidanceLessonId time = GuidanceLessonId.scheduleFirstItem;
    const GuidanceLessonId find = GuidanceLessonId.reviewTimeline;
    const Set<GuidanceLessonId> all = <GuidanceLessonId>{create, time, find};

    AdaptiveGuidanceState shape({
      Set<GuidanceMilestone> milestones = const <GuidanceMilestone>{},
      bool receipt = false,
      Set<GuidanceLessonId> skip = const <GuidanceLessonId>{},
      Set<GuidanceLessonId> later = const <GuidanceLessonId>{},
      Set<GuidanceLessonId> reopen = const <GuidanceLessonId>{},
      Set<GuidanceLessonId> skipStep = const <GuidanceLessonId>{},
      Set<GuidanceLessonId> replay = const <GuidanceLessonId>{},
    }) => AdaptiveGuidanceState(
      milestones: <GuidanceMilestone, DateTime>{
        for (final GuidanceMilestone m in milestones) m: at,
      },
      counts: const <GuidanceMilestone, int>{},
      skippedLessons: skip,
      completedLessons: const <GuidanceLessonId>{},
      laterLessons: later,
      untilReopenedLessons: reopen,
      skippedCoreSteps: skipStep,
      replayLessons: replay,
      expectedFirstRunCreatorTaskIds: receipt
          ? const <String>{'saved-task'}
          : const <String>{},
    );

    const GuidanceMilestone item = GuidanceMilestone.firstItem;
    const GuidanceMilestone sched = GuidanceMilestone.firstSchedule;
    const GuidanceMilestone review = GuidanceMilestone.firstTimelineReview;
    const CoreGuideStatus active = CoreGuideStatus.active;
    const CoreGuideStatus paused = CoreGuideStatus.paused;
    const CoreGuideStatus skipped = CoreGuideStatus.skipped;
    const CoreGuideStatus complete = CoreGuideStatus.complete;

    final List<
      (String, AdaptiveGuidanceState, GuidanceLessonId?, CoreGuideStatus)
    >
    table =
        <(String, AdaptiveGuidanceState, GuidanceLessonId?, CoreGuideStatus)>[
          ('new account', shape(), create, active),
          ('firstItem only', shape(milestones: {item}), time, active),
          (
            'firstItem + time, no receipt',
            shape(milestones: {item, sched}),
            create,
            active,
          ),
          (
            'firstItem + receipt',
            shape(milestones: {item}, receipt: true),
            find,
            active,
          ),
          (
            'firstItem + time + receipt',
            shape(milestones: {item, sched}, receipt: true),
            find,
            active,
          ),
          ('receipt only', shape(receipt: true), create, active),
          (
            'all three milestones',
            shape(milestones: {item, sched, review}),
            null,
            complete,
          ),
          (
            'review only (time lost)',
            shape(milestones: {review}),
            null,
            complete,
          ),
          (
            'returning account',
            shape(milestones: {GuidanceMilestone.returningAccount}),
            null,
            complete,
          ),
          ('whole guide skipped', shape(skip: all), null, skipped),
          (
            'whole guide skipped + receipt',
            shape(milestones: {item}, receipt: true, skip: all),
            null,
            skipped,
          ),
          ('whole guide paused', shape(later: all), null, paused),
          (
            'whole guide paused + receipt',
            shape(milestones: {item}, receipt: true, later: all),
            null,
            paused,
          ),
          ('hidden until reopened', shape(reopen: all), null, paused),
          (
            'hidden until reopened + receipt',
            shape(milestones: {item}, receipt: true, reopen: all),
            null,
            paused,
          ),
          ('skip of step 1 add only', shape(skip: {create}), null, skipped),
          (
            'skip of the time step only',
            shape(milestones: {item}, skip: {time}),
            null,
            skipped,
          ),
          (
            'skip of the time step + receipt',
            shape(milestones: {item}, receipt: true, skip: {time}),
            null,
            skipped,
          ),
          (
            'pause of the time step + receipt',
            shape(milestones: {item}, receipt: true, later: {time}),
            null,
            paused,
          ),
          (
            'skip of step 2 only, receipt',
            shape(milestones: {item, sched}, receipt: true, skip: {find}),
            null,
            skipped,
          ),
          (
            'pause of step 2 only, receipt',
            shape(milestones: {item, sched}, receipt: true, later: {find}),
            null,
            paused,
          ),
          (
            'step 1 skipped, nothing saved',
            shape(skipStep: {create, time}),
            null,
            skipped,
          ),
          (
            'step 1 skipped, receipt',
            shape(skipStep: {create, time}, receipt: true),
            find,
            active,
          ),
          (
            'step 2 skipped',
            shape(milestones: {item, sched}, skipStep: {find}),
            null,
            skipped,
          ),
          ('every step skipped', shape(skipStep: all), null, skipped),
          (
            'restarted, done before',
            shape(milestones: {item, sched, review}, replay: all),
            create,
            active,
          ),
          (
            'restarted, add done again',
            shape(milestones: {item, sched, review}, replay: {time, find}),
            time,
            active,
          ),
          (
            'restarted, add done again + receipt',
            shape(
              milestones: {item, sched, review},
              replay: {time, find},
              receipt: true,
            ),
            find,
            active,
          ),
          (
            'restarted + time skipped + receipt',
            shape(
              milestones: {item, sched, review},
              replay: {time, find},
              receipt: true,
              skip: {time},
            ),
            null,
            skipped,
          ),
          (
            'restarted, then paused',
            shape(milestones: {item, sched, review}, replay: all, later: all),
            null,
            paused,
          ),
        ];

    for (final (
          String name,
          AdaptiveGuidanceState state,
          GuidanceLessonId? lesson,
          CoreGuideStatus status,
        )
        in table) {
      test(name, () {
        expect(state.activeCoreLesson, lesson, reason: name);
        expect(state.coreGuideStatus, status, reason: name);
      });
    }
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
