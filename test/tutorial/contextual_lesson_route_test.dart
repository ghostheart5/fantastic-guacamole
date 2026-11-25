import 'package:fantastic_guacamole/app/router/route_paths.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/daily_decision_intelligence_provider.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/tutorial/adaptive_guidance.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// After the first-run guide, a contextual lesson describes one screen and
/// may appear only on that screen.
void main() {
  final DateTime coreDoneAt = DateTime.utc(2026, 8, 18);
  final DateTime later = coreDoneAt.add(const Duration(days: 3));

  // Every branch of the former cross-route fallback chain, plus repeated
  // deferral, which used to pick the Schedule lesson from any screen.
  final Map<String, (AdaptiveGuidanceState, DailyDecisionIntelligence)>
  fallbackStates = <String, (AdaptiveGuidanceState, DailyDecisionIntelligence)>{
    'replan suggestion': (
      _coreDone(coreDoneAt),
      _decision(replanAction: 'Move Task A to 3 pm.'),
    ),
    'low confidence': (_coreDone(coreDoneAt), _decision(confidence: .2)),
    'zero observed outcomes': (
      _coreDone(coreDoneAt),
      _decision(observedOutcomes: 0),
    ),
    'unreviewed Today': (_coreDone(coreDoneAt), _decision()),
    'warning': (
      _coreDone(coreDoneAt),
      _decision(warning: 'Too much is scheduled for Friday.'),
    ),
    'repeated deferral': (_coreDone(coreDoneAt, deferrals: 2), _decision()),
    'everything at once': (
      _coreDone(coreDoneAt, deferrals: 2),
      _decision(
        replanAction: 'Move Task A to 3 pm.',
        confidence: .1,
        observedOutcomes: 0,
        warning: 'Too much is scheduled for Friday.',
      ),
    ),
  };

  const List<String> routesWithoutALesson = <String>[
    RoutePaths.settings,
    RoutePaths.creator,
    RoutePaths.creatorGoals,
    RoutePaths.notifications,
    RoutePaths.advancedRoot,
    RoutePaths.home,
    RoutePaths.shell,
    '/goals',
    '/habits',
  ];

  for (final MapEntry<
        String,
        (AdaptiveGuidanceState, DailyDecisionIntelligence)
      >
      entry
      in fallbackStates.entries) {
    test('no lesson on a screen without one (${entry.key})', () {
      final (AdaptiveGuidanceState state, DailyDecisionIntelligence decision) =
          entry.value;
      for (final String route in routesWithoutALesson) {
        expect(
          state.nextIntervention(
            currentRoute: route,
            decision: decision,
            now: later,
          ),
          isNull,
          reason: '$route must not show a lesson about another screen',
        );
      }
    });

    test('a finished lesson is not replaced by one about another screen '
        '(${entry.key})', () {
      final (AdaptiveGuidanceState base, DailyDecisionIntelligence decision) =
          entry.value;
      for (final (String route, GuidanceLessonId own) in _lessonRoutes) {
        final AdaptiveGuidanceState ownDone = _withCompleted(base, own);
        expect(
          ownDone.nextIntervention(
            currentRoute: route,
            decision: decision,
            now: later,
          ),
          isNull,
          reason: '$route has finished its own lesson',
        );
      }
    });
  }

  test('each lesson still appears on its own screen', () {
    final AdaptiveGuidanceState state = _coreDone(coreDoneAt);
    for (final (String route, GuidanceLessonId own) in _lessonRoutes) {
      final GuidanceLesson? lesson = state.nextIntervention(
        currentRoute: route,
        decision: _decision(),
        now: later,
      );
      expect(lesson?.id, own, reason: route);
      expect(lesson?.route, route);
    }
  });

  test('repeated deferral help appears only on Schedule', () {
    final AdaptiveGuidanceState state = _coreDone(coreDoneAt, deferrals: 2);
    final GuidanceLesson? onSchedule = state.nextIntervention(
      currentRoute: RoutePaths.timeline,
      decision: _decision(),
      now: coreDoneAt.add(const Duration(minutes: 5)),
    );
    expect(onSchedule?.id, GuidanceLessonId.timelineExecution);
    expect(onSchedule?.title, 'Try a smaller step or a different time');
    // Today shows its own lesson, not the Schedule recovery help.
    expect(
      state
          .nextIntervention(
            currentRoute: RoutePaths.nexus,
            decision: _decision(),
            now: later,
          )
          ?.id,
      GuidanceLessonId.nexus,
    );
  });

  test('"Continue here" completes the lesson for the account', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final ProviderContainer first = _container('continue-here-user');
    await first.read(adaptiveGuidanceProvider.future);
    await first
        .read(adaptiveGuidanceProvider.notifier)
        .completeLesson(GuidanceLessonId.siConsole);
    expect(
      first.read(adaptiveGuidanceProvider).requireValue.completedLessons,
      contains(GuidanceLessonId.siConsole),
    );
    first.dispose();

    final ProviderContainer reopened = _container('continue-here-user');
    addTearDown(reopened.dispose);
    final AdaptiveGuidanceState restored = await reopened.read(
      adaptiveGuidanceProvider.future,
    );
    expect(restored.completedLessons, contains(GuidanceLessonId.siConsole));
    // Not a skip: "Not now" keeps its own stored meaning.
    expect(
      restored.skippedLessons,
      isNot(contains(GuidanceLessonId.siConsole)),
    );

    final ProviderContainer otherAccount = _container('someone-else');
    addTearDown(otherAccount.dispose);
    expect(
      (await otherAccount.read(
        adaptiveGuidanceProvider.future,
      )).completedLessons,
      isNot(contains(GuidanceLessonId.siConsole)),
    );
  });

  test('"Continue here" never finishes a first-run guide step', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final ProviderContainer container = _container('core-continue-user');
    addTearDown(container.dispose);
    await container.read(adaptiveGuidanceProvider.future);
    await container
        .read(adaptiveGuidanceProvider.notifier)
        .completeLesson(GuidanceLessonId.createFirstItem);
    final AdaptiveGuidanceState state = container
        .read(adaptiveGuidanceProvider)
        .requireValue;
    expect(state.completedLessons, isEmpty);
    expect(state.activeCoreLesson, GuidanceLessonId.createFirstItem);
  });

  test('older stored guidance loads unchanged and stays dismissed', () async {
    final String namespace = AccountStorageScope.authenticated(
      'stored-guidance-user',
    ).v2Namespace!;
    final String prefix = 'adaptive_guidance_v3.$namespace';
    final int at = coreDoneAt.millisecondsSinceEpoch;
    SharedPreferences.setMockInitialValues(<String, Object>{
      '$prefix.firstItem.at': at,
      '$prefix.firstItem.count': 1,
      '$prefix.firstSchedule.at': at,
      '$prefix.firstSchedule.count': 1,
      '$prefix.firstTimelineReview.at': at,
      '$prefix.firstTimelineReview.count': 1,
      '$prefix.complete.createFirstItem': true,
      '$prefix.complete.scheduleFirstItem': true,
      '$prefix.complete.reviewTimeline': true,
      '$prefix.skip.siConsole': true,
      '$prefix.later.smartPlanner': true,
      '$prefix.complete.nexus': true,
      '$prefix.firstTrajectoryReview.at': at,
      '$prefix.firstTrajectoryReview.count': 1,
    });
    final ProviderContainer container = _container('stored-guidance-user');
    addTearDown(container.dispose);
    final AdaptiveGuidanceState state = await container.read(
      adaptiveGuidanceProvider.future,
    );
    expect(state.coreComplete, isTrue);
    expect(state.skippedLessons, <GuidanceLessonId>{
      GuidanceLessonId.siConsole,
    });
    expect(state.laterLessons, <GuidanceLessonId>{
      GuidanceLessonId.smartPlanner,
    });
    expect(
      state.completedLessons,
      containsAll(<GuidanceLessonId>{
        GuidanceLessonId.nexus,
        GuidanceLessonId.trajectoryEngine,
      }),
    );
    for (final String route in <String>[
      RoutePaths.siConsole,
      RoutePaths.smartPlanner,
      RoutePaths.nexus,
      RoutePaths.trajectoryEngine,
    ]) {
      expect(
        state.nextIntervention(
          currentRoute: route,
          decision: _decision(confidence: .1, observedOutcomes: 0),
          now: later,
        ),
        isNull,
        reason: '$route was already dismissed or completed',
      );
    }
    expect(
      state
          .nextIntervention(
            currentRoute: RoutePaths.progression,
            decision: _decision(),
            now: later,
          )
          ?.id,
      GuidanceLessonId.progression,
    );
  });
}

const List<(String, GuidanceLessonId)> _lessonRoutes =
    <(String, GuidanceLessonId)>[
      (RoutePaths.nexus, GuidanceLessonId.nexus),
      (RoutePaths.smartPlanner, GuidanceLessonId.smartPlanner),
      (RoutePaths.timeline, GuidanceLessonId.timelineExecution),
      (RoutePaths.siConsole, GuidanceLessonId.siConsole),
      (RoutePaths.trajectoryEngine, GuidanceLessonId.trajectoryEngine),
      (RoutePaths.progression, GuidanceLessonId.progression),
    ];

AdaptiveGuidanceState _coreDone(DateTime at, {int deferrals = 0}) {
  return AdaptiveGuidanceState(
    milestones: <GuidanceMilestone, DateTime>{
      GuidanceMilestone.firstItem: at,
      GuidanceMilestone.firstSchedule: at,
      GuidanceMilestone.firstTimelineReview: at,
      if (deferrals > 0) GuidanceMilestone.firstTaskDeferral: at,
    },
    counts: <GuidanceMilestone, int>{
      if (deferrals > 0) GuidanceMilestone.firstTaskDeferral: deferrals,
    },
    skippedLessons: const <GuidanceLessonId>{},
    completedLessons: const <GuidanceLessonId>{
      GuidanceLessonId.createFirstItem,
      GuidanceLessonId.scheduleFirstItem,
      GuidanceLessonId.reviewTimeline,
    },
  );
}

AdaptiveGuidanceState _withCompleted(
  AdaptiveGuidanceState state,
  GuidanceLessonId lesson,
) {
  return AdaptiveGuidanceState(
    milestones: state.milestones,
    counts: state.counts,
    skippedLessons: state.skippedLessons,
    completedLessons: <GuidanceLessonId>{...state.completedLessons, lesson},
  );
}

DailyDecisionIntelligence _decision({
  String? replanAction,
  double confidence = .7,
  int observedOutcomes = 1,
  String warning =
      'No material constraint is supported by the current evidence.',
}) {
  return DailyDecisionIntelligence(
    primaryAction: 'Work on Task A',
    momentum: '60% steady',
    trajectory: 'Stable',
    energy: '70% energy',
    warning: warning,
    recovery: 'Protect a short recovery window.',
    recommendedAction: 'Work on Task A',
    rationale: 'Task A is the highest feasible item.',
    changeSummary: 'Task A moved up.',
    evidence: const <String>['priority=5'],
    confidence: confidence,
    observedOutcomes: observedOutcomes,
    replanAction: replanAction,
  );
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
