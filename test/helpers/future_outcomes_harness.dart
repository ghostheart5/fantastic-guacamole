import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/domain/operating_system/operating_system_contract.dart';
import 'package:fantastic_guacamole/domain/predictive/predictive_planning_contract.dart';
import 'package:fantastic_guacamole/domain/trajectory/trajectory_consequence_contract.dart';
import 'package:fantastic_guacamole/domain/trajectory/trajectory_forecast_receipt.dart';
import 'package:fantastic_guacamole/engine/trajectory/future_consequence_engine.dart';
import 'package:fantastic_guacamole/features/trajectory_engine/ui/trajectory_engine_screen.dart';
import 'package:fantastic_guacamole/l10n/chronospark_localizations.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_consequence_provider.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_engine_model_provider.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_forecast_ledger_provider.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_habit_provider.dart';
import 'package:fantastic_guacamole/ui/widgets/plain/plain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'trajectory_test_fixture.dart';

/// Shared set-up for the Future outcomes screen tests: a forecast whose range
/// fields (tasks in the range, expected completions, workload) are worked out
/// the way the live provider does, with options of every common kind.

/// Four tasks spread over the ranges: two count at 7 days, three at 30 and
/// all four at 90 (the undated one counts everywhere).
List<TrajectoryTaskNode> futureOutcomesTasks() => <TrajectoryTaskNode>[
  TrajectoryTaskNode(
    id: 'task-a',
    title: 'Draft the proposal',
    priority: 4,
    estimatedMinutes: 60,
    goalId: 'goal-release',
    dueAt: trajectoryFixtureNow.add(const Duration(days: 3)),
  ),
  TrajectoryTaskNode(
    id: 'task-b',
    title: 'Prepare the review',
    priority: 3,
    estimatedMinutes: 120,
    dueAt: trajectoryFixtureNow.add(const Duration(days: 20)),
  ),
  TrajectoryTaskNode(
    id: 'task-c',
    title: 'Plan the quarter',
    priority: 2,
    estimatedMinutes: 60,
    dueAt: trajectoryFixtureNow.add(const Duration(days: 60)),
  ),
  const TrajectoryTaskNode(
    id: 'task-d',
    title: 'Tidy the inbox',
    priority: 1,
    estimatedMinutes: 30,
  ),
];

TrajectoryBaseline futureOutcomesBaseline({
  int days = 7,
  String accountScope = 'v2.test-account',
  String revision = 'future-outcomes-r1',
  int completedInWindow = 1,
  int observationCount = 12,
  int dailyFreeMinutes = 120,
  PredictiveEvidenceOrigin availabilityOrigin =
      PredictiveEvidenceOrigin.observed,
  List<String> assumptions = const <String>[],
}) {
  final List<TrajectoryTaskNode> tasks = futureOutcomesTasks();
  final TrajectoryBaseline base = trajectoryTestBaseline(
    accountScope: accountScope,
    tasks: tasks,
    dailyFreeMinutes: dailyFreeMinutes,
    completedInWindow: completedInWindow,
    horizonDays: days,
    observationCount: observationCount,
    availabilityOrigin: availabilityOrigin,
  );
  TrajectoryHorizonWorkload range(int d) =>
      FutureConsequenceEngine.horizonWorkload(
        tasks: tasks,
        now: trajectoryFixtureNow,
        horizonDays: d,
        completedLast7Days: completedInWindow,
      );
  int load(int d) => FutureConsequenceEngine.capacityLoad(
    requiredMinutes: range(d).requiredMinutes,
    dailyFreeMinutes: dailyFreeMinutes,
    days: d,
  );
  final TrajectoryHorizonWorkload selected = range(days);
  return TrajectoryBaseline(
    accountScope: base.accountScope,
    revision: revision,
    observedAt: base.observedAt,
    evidenceWindow: base.evidenceWindow,
    momentum: base.momentum,
    pressure: load(7),
    energy: base.energy,
    completedInWindow: completedInWindow,
    deferredInWindow: base.deferredInWindow,
    observationCount: observationCount,
    availableMinutes: base.availableMinutes,
    occupiedMinutes: base.occupiedMinutes,
    unscheduledMinutes: base.unscheduledMinutes,
    tasks: tasks,
    goals: <TrajectoryGoalNode>[
      TrajectoryGoalNode(
        id: 'goal-release',
        title: 'Release candidate',
        targetDate: trajectoryFixtureNow.add(const Duration(days: 4)),
        linkedTaskIds: const <String>['task-a'],
      ),
    ],
    blocks: const <TrajectoryBlockNode>[],
    timelineSignals: const <TrajectoryTimelineSignal>[],
    progression: base.progression,
    confidence: base.confidence,
    sourceRevisions: base.sourceRevisions,
    energyOrigin: base.energyOrigin,
    availabilityOrigin: availabilityOrigin,
    horizonDays: days,
    dailyFreeMinutes: dailyFreeMinutes,
    tasksInHorizon: selected.taskCount,
    requiredMinutesInHorizon: selected.requiredMinutes,
    expectedCompletionsInHorizon: selected.expectedCompletions,
    assumptions: assumptions,
    pressureInHorizon: load(days),
  );
}

/// The options: keep going, the planner, finish the proposal, remove the
/// inbox task and put the proposal off. [reduceId] renames the remove option
/// (a refresh can give an option a new id while its kind stays the same);
/// [withReduce] false leaves that kind out.
TrajectoryComparison futureOutcomesComparison({
  int days = 7,
  TrajectoryBaseline? baseline,
  String reduceId = 'remove-task-d',
  bool withReduce = true,
}) {
  final TrajectoryBaseline resolved =
      baseline ?? futureOutcomesBaseline(days: days);
  final Duration horizon = Duration(days: days);
  return const FutureConsequenceEngine().compare(
    baseline: resolved,
    generatedAt: trajectoryFixtureNow,
    interventions: <TrajectoryIntervention>[
      TrajectoryIntervention(
        id: 'maintain',
        type: TrajectoryInterventionType.maintainCourse,
        title: 'Maintain current course',
        horizon: horizon,
        description: 'Keep the present plan unchanged.',
      ),
      TrajectoryIntervention(
        id: 'planner',
        type: TrajectoryInterventionType.applySmartPlanner,
        title: 'Keep the suggested plan',
        horizon: horizon,
        description: 'Protect the highest-value feasible block.',
        subjectId: 'task-a',
      ),
      TrajectoryIntervention(
        id: 'complete-task-a',
        type: TrajectoryInterventionType.completeTask,
        title: 'Complete Draft the proposal',
        horizon: horizon,
        description: 'Finish the proposal in its planned time.',
        subjectId: 'task-a',
      ),
      if (withReduce)
        TrajectoryIntervention(
          id: reduceId,
          type: TrajectoryInterventionType.reduceScope,
          title: 'Reduce lower-priority scope',
          horizon: horizon,
          description: 'Take the inbox task out of this range.',
          subjectId: 'task-d',
        ),
      TrajectoryIntervention(
        id: 'delay-task-a',
        type: TrajectoryInterventionType.delayTask,
        title: 'Delay the milestone',
        horizon: horizon,
        description: 'Move the proposal by two days.',
        subjectId: 'task-a',
        delay: const Duration(days: 2),
      ),
    ],
  );
}

TrajectoryEngineModel futureOutcomesModel({
  int days = 7,
  TrajectoryComparison? comparison,
  TrajectoryEngineStatus status = TrajectoryEngineStatus.ready,
  DecisionIntelligence? decision,
}) {
  final TrajectoryEngineModel fixture = trajectoryTestEngineModel();
  return TrajectoryEngineModel(
    status: status,
    summary: fixture.summary,
    momentum: fixture.momentum,
    comparison: comparison ?? futureOutcomesComparison(days: days),
    decisionIntelligence: decision,
    statusDetail: fixture.statusDetail,
    hasAvailableNetworkInterface: true,
  );
}

/// Today's planning summary as the operating-system provider builds it, with
/// its own producer sentences. [firstSummary] gives the first one (no earlier
/// snapshot), whose change line comes from the delta engine.
DecisionIntelligence futureOutcomesDecision({bool firstSummary = false}) {
  final DateTime now = trajectoryFixtureNow;
  OperatingSnapshot snapshot({
    required int momentum,
    required int pressure,
    required int overdue,
    required int completed,
  }) => OperatingSnapshot(
    accountScope: 'v2.test-account',
    observedAt: now,
    sourceRevisions: <String, String>{'tasks': '$completed'},
    activeGoalCount: 1,
    actionableCount: 4,
    overdueCount: overdue,
    completedToday: completed,
    energy: .64,
    fatigue: .2,
    momentum: momentum,
    pressure: pressure,
    topActionId: 'task-a',
    topActionLabel: 'Draft the proposal',
    activeRisks: const <String>['One overdue task'],
    evidenceCoverage: .9,
  );
  final OperatingSnapshot current = snapshot(
    momentum: 61,
    pressure: 58,
    overdue: 1,
    completed: 2,
  );
  final OperatingSnapshot? previous = firstSummary
      ? null
      : snapshot(momentum: 52, pressure: 66, overdue: 2, completed: 1);
  return DecisionIntelligence(
    snapshot: current,
    delta: const OperatingDeltaEngine().compare(
      previous: previous,
      current: current,
      comparedAt: now,
    ),
    decision: OperatingDecisionReceipt(
      subjectId: 'task-a',
      recommendedAction: 'Draft the proposal',
      rationale: 'Draft the proposal ranks first for its deadline and value.',
      whyItMatters:
          'It reduces current schedule risk and prevents overdue pressure from compounding.',
      consequenceOfDelay:
          'Waiting can increase rollover pressure and reduce schedule flexibility.',
      generatedAt: now,
      // Far ahead, so the action stays enabled whatever the test clock.
      expiresAt: DateTime.utc(2100),
      confidence: OperatingConfidence.moderate,
      evidence: const <OperatingEvidence>[],
      actionIntent: const OperatingActionIntent(
        id: 'action-a',
        type: OperatingActionType.openTimeline,
        label: 'Review on Schedule',
        destination: '/timeline',
        targetEntityId: 'task-a',
      ),
      sourceRevisions: const <String, String>{'tasks': '2'},
      modelVersion: 'operating-test-v1',
      assumptions: const <String>[
        'Deterministic ranking is decision support, not a guaranteed outcome.',
      ],
    ),
    acknowledgedSnapshotId: null,
  );
}

/// Two habits: one with a projected line, one without enough history yet.
TrajectoryHabitLines futureOutcomesHabitLines(int days) => TrajectoryHabitLines(
  status: TrajectoryHabitLinesStatus.ready,
  horizonDays: days,
  nodes: <TrajectoryHabitNode>[
    TrajectoryHabitNode(
      habitId: 'habit-walk',
      title: 'Morning walk',
      cadence: HabitCadence.daily,
      closedPeriodsJudged: 14,
      completedPeriods: 10,
      rate: 10 / 14,
      expectedPeriods: days,
      projectedCheckIns: TrajectoryExpectedCompletions(
        low: (days * .5).round(),
        mid: (days * .7).round(),
        high: (days * .9).round(),
      ),
      checkedInThisPeriod: false,
      evidence: TrajectoryHabitEvidence.enough,
    ),
    const TrajectoryHabitNode(
      habitId: 'habit-read',
      title: 'Read a chapter',
      cadence: HabitCadence.weekly,
      closedPeriodsJudged: 2,
      completedPeriods: 2,
      rate: null,
      expectedPeriods: 1,
      projectedCheckIns: null,
      checkedInThisPeriod: false,
      evidence: TrajectoryHabitEvidence.notEnoughHistory,
    ),
  ],
  revision: 'habits-$days',
);

const TrajectoryCalibrationSummary futureOutcomesCalibration =
    TrajectoryCalibrationSummary(
      resolvedForecasts: 0,
      momentumMeanAbsoluteError: 0,
      pressureMeanAbsoluteError: 0,
      intervalCoverage: 0,
      state: PredictiveCalibrationState.provisional,
    );

/// Pumps the screen. [modelFor] and [habitsFor] follow the selected range.
/// Pass [defaultModel] or [defaultHabits] false when [extraOverrides] supply
/// that provider instead.
Future<ProviderContainer> pumpFutureOutcomes(
  WidgetTester tester, {
  TrajectoryEngineModel Function(int days)? modelFor,
  TrajectoryHabitLines Function(int days)? habitsFor,
  Locale locale = const Locale('en'),
  ThemeData? theme,
  Size size = const Size(900, 2400),
  double textScale = 1,
  List<Override> extraOverrides = const <Override>[],
  bool defaultModel = true,
  bool defaultHabits = true,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        if (defaultModel)
          trajectoryEngineModelProvider.overrideWith(
            (Ref ref) =>
                (modelFor ??
                (int d) => futureOutcomesModel(
                  days: d,
                  // Today's planning summary is on by default, so every
                  // screen test also reads it (its first-summary wording).
                  decision: futureOutcomesDecision(firstSummary: true),
                ))(ref.watch(trajectoryHorizonDaysProvider)),
          ),
        if (defaultHabits)
          trajectoryHabitLinesProvider.overrideWith(
            (Ref ref) => (habitsFor ?? futureOutcomesHabitLines)(
              ref.watch(trajectoryHorizonDaysProvider),
            ),
          ),
        trajectoryCalibrationSummaryProvider.overrideWithValue(
          const AsyncValue<TrajectoryCalibrationSummary>.data(
            futureOutcomesCalibration,
          ),
        ),
        ...extraOverrides,
      ],
      child: MaterialApp(
        theme: theme,
        locale: locale,
        supportedLocales: const <Locale>[Locale('en'), Locale('es')],
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          ChronoSparkLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (BuildContext context, Widget? child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const TrajectoryEngineScreen(),
      ),
    ),
  );
  await settleFutureOutcomes(tester);
  return ProviderScope.containerOf(
    tester.element(find.byType(TrajectoryEngineScreen)),
  );
}

Future<void> settleFutureOutcomes(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump();
}

Finder get futureOutcomesScroll => find.byType(Scrollable).first;

/// Scrolls [finder] into view and taps it.
Future<void> tapFutureOutcomes(WidgetTester tester, Finder finder) async {
  await revealFutureOutcomes(tester, finder);
  await tester.tap(finder.hitTestable().first);
  await settleFutureOutcomes(tester);
}

/// Brings [finder] into view, building it first if it is still off screen.
Future<void> revealFutureOutcomes(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder.first,
      200,
      scrollable: futureOutcomesScroll,
    );
  }
  await tester.ensureVisible(finder.first);
  await tester.pump();
}

/// Opens every disclosure on the screen, including ones that appear inside
/// others, until none is left closed.
Future<void> openAllDisclosures(WidgetTester tester) async {
  final Set<String> opened = <String>{};
  for (int round = 0; round < 12; round++) {
    final List<PlainDisclosure> closed = tester
        .widgetList<PlainDisclosure>(find.byType(PlainDisclosure))
        .where((PlainDisclosure d) => !opened.contains(d.title))
        .toList();
    if (closed.isEmpty) return;
    for (final PlainDisclosure disclosure in closed) {
      opened.add(disclosure.title);
      final Finder title = find.descendant(
        of: find.byWidget(disclosure),
        matching: find.text(disclosure.title),
      );
      await tester.ensureVisible(title.first);
      await tester.pump();
      await tester.tap(title.first);
      await settleFutureOutcomes(tester);
    }
  }
}

/// Every visible text on the screen (snackbars excluded).
List<String> futureOutcomesTexts(WidgetTester tester) => tester
    .widgetList<Text>(
      find.descendant(
        of: find.byType(TrajectoryEngineScreen),
        matching: find.byType(Text),
      ),
    )
    .map((Text t) => t.data ?? t.textSpan?.toPlainText() ?? '')
    .where((String s) => s.isNotEmpty)
    .toList();

/// A value a test can change while the screen is shown.
class FutureOutcomesValue<T> extends Notifier<T> {
  FutureOutcomesValue(this.initial);

  final T initial;

  @override
  T build() => initial;

  void set(T value) => state = value;
}
