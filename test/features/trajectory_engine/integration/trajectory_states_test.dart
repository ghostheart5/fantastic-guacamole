import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/repositories/trajectory_forecast_ledger_repository.dart';
import 'package:fantastic_guacamole/domain/predictive/predictive_planning_contract.dart';
import 'package:fantastic_guacamole/domain/trajectory/trajectory_consequence_contract.dart';
import 'package:fantastic_guacamole/domain/trajectory/trajectory_forecast_receipt.dart';
import 'package:fantastic_guacamole/engine/trajectory/future_consequence_engine.dart';
import 'package:fantastic_guacamole/state/models/trajectory_summary_view.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_engine_model_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/trajectory_screen_harness.dart';
import '../../../helpers/trajectory_test_fixture.dart';

/// Future outcomes states and progressive disclosure: ready, empty, error,
/// learning, the range choice, the what-if and the task follow-through.
/// (Split out of the former trajectory_engine_integration_test.dart.)
void main() {
  for (final language in ['en', 'es']) {
    testWidgets('keep going reads as unchanged at 7, 30 and 90 days in '
        '$language', (tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final scope = AccountStorageScope.authenticated('test-account');
      final steady = language == 'es'
          ? 'la carga sin cambios'
          : 'workload unchanged';
      final Set<int> projected = <int>{};
      for (final int days in const <int>[7, 30, 90]) {
        final comparison = trajectoryTestComparison(
          horizonDays: days,
          baseline: trajectoryTestBaseline(
            accountScope: scope.v2Namespace!,
            horizonDays: days,
          ),
        );
        final outcome = comparison.outcomes.firstWhere(
          (value) => value.intervention.id == 'maintain',
        );
        projected.add(outcome.projectedPressure);
        await tester.pumpWidget(
          trajectoryScreenHarness(
            model: trajectoryModelWithOutcomes(comparison, [outcome]),
            locale: Locale(language),
            repository: TrajectoryForecastLedgerRepository(
              store: TrajectoryMemoryStore(),
              scope: scope,
            ),
          ),
        );
        await pumpTrajectoryTransition(tester);
        await tester.scrollUntilVisible(
          find.textContaining(steady).first,
          250,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.textContaining(steady), findsWidgets, reason: '$days');
        expect(
          find.textContaining(
            language == 'es' ? 'la carga bajando' : 'workload down',
          ),
          findsNothing,
          reason: '$days',
        );
      }
      // The projected workload itself still differs between ranges.
      expect(projected.length, greaterThan(1));
    });
  }

  for (final historyKind in ['pooled', 'unknown', 'unavailable']) {
    for (final language in ['en', 'es']) {
      testWidgets(
        'task evidence scope leads percentages in $language history=$historyKind',
        (tester) async {
          await tester.binding.setSurfaceSize(const Size(900, 1800));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final fixture = trajectoryTestEngineModel();
          final bool pooled = historyKind == 'pooled';
          final int samples = historyKind == 'unavailable' ? 0 : 5;
          final summary = TrajectorySummaryView(
            pendingTasks: fixture.summary.pendingTasks,
            completedTasks: fixture.summary.completedTasks,
            completedToday: fixture.summary.completedToday,
            level: fixture.summary.level,
            streak: fixture.summary.streak,
            energy: fixture.summary.energy,
            momentum: fixture.summary.momentum,
            adaptability: fixture.summary.adaptability,
            lastCompletionXp: fixture.summary.lastCompletionXp,
            lastCompletionQuality: fixture.summary.lastCompletionQuality,
            pressureIndex: fixture.summary.pressureIndex,
            behaviorDivergence: fixture.summary.behaviorDivergence,
            alert: fixture.summary.alert,
            predictionTitle: 'Unmatched task',
            predictionOutcome: 'Higher observed follow-through',
            predictionProbability: samples == 0 ? .5 : .86,
            predictionLowerBound: samples == 0 ? 0 : .67,
            predictionUpperBound: 1,
            predictionSampleSize: samples,
            predictionExplanation: pooled
                ? 'No exact task history exists, so this estimate uses all recorded completed and skipped task outcomes.'
                : samples == 0
                ? 'Account storage is not ready.'
                : 'The source does not identify whether task history matches.',
          );
          await tester.pumpWidget(
            trajectoryScreenHarness(
              locale: Locale(language),
              model: TrajectoryEngineModel(
                status: TrajectoryEngineStatus.ready,
                summary: summary,
                momentum: fixture.momentum,
                comparison: fixture.comparison,
                statusDetail: fixture.statusDetail,
                hasAvailableNetworkInterface: true,
              ),
            ),
          );
          await tester.pump();
          // Pace uses its actual 0–100 scale, not a percent probability.
          final scorePrefix = language == 'en'
              ? 'Pace about'
              : 'Ritmo de alrededor de';
          final scale = language == 'en' ? 'of 100' : 'de 100';
          expect(
            find.textContaining(
              RegExp('$scorePrefix \\d+ $scale \\(\\d+–\\d+\\)'),
            ),
            findsWidgets,
          );
          expect(
            find.textContaining(RegExp('$scorePrefix \\d+%')),
            findsNothing,
          );
          await tapTrajectory(
            tester,
            find.text(
              language == 'en' ? 'What this is based on' : 'En qué se basa',
            ),
          );
          final lead = find.text(
            samples == 0
                ? language == 'en'
                      ? 'No recorded task outcomes are available for this estimate.'
                      : 'No hay resultados de tareas registrados disponibles para esta estimación.'
                : pooled
                ? language == 'en'
                      ? 'From 5 finished or skipped tasks in your follow-through history (any time). This task has no history yet.'
                      : 'De 5 tareas terminadas u omitidas en tu historial de cumplimiento (de cualquier fecha). Esta tarea aún no tiene historial.'
                : language == 'en'
                ? 'From 5 times you finished or skipped this task (any time).'
                : 'De 5 veces que terminaste u omitiste esta tarea (de cualquier fecha).',
          );
          await tester.scrollUntilVisible(
            lead,
            150,
            scrollable: find.byType(Scrollable).first,
          );
          expect(lead, findsOneWidget);
          // Preserve the separate probability estimate and statistical interval.
          final estimate = find.textContaining(
            samples == 0
                ? language == 'en'
                      ? 'Estimated chance of finishing it: 50% (likely 0% to 100%)'
                      : 'Probabilidad estimada de terminarla: 50% (probablemente entre 0% y 100%)'
                : language == 'en'
                ? 'Estimated chance of finishing it: 86% (likely 67% to 100%)'
                : 'Probabilidad estimada de terminarla: 86% (probablemente entre 67% y 100%)',
          );
          expect(estimate, findsOneWidget);
          expect(
            tester.getTopLeft(lead).dy,
            lessThan(tester.getTopLeft(estimate).dy),
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('composing delay selects the revision-qualified delay outcome', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final fixture = trajectoryTestEngineModel();
    final baseline = trajectoryTestBaseline();
    final generated = const FutureConsequenceEngine().compare(
      baseline: baseline,
      generatedAt: trajectoryFixtureNow,
      interventions: [
        TrajectoryIntervention(
          id: 'complete',
          type: TrajectoryInterventionType.completeTask,
          title: 'Complete QA',
          horizon: const Duration(days: 7),
          description: 'Original complete result',
          subjectId: 'task-launch',
        ),
        TrajectoryIntervention(
          id: 'custom-delay-task-launch-1-7',
          type: TrajectoryInterventionType.delayTask,
          title: 'Delay QA',
          horizon: const Duration(days: 7),
          description: 'Selected custom delay result',
          subjectId: 'task-launch',
          delay: const Duration(days: 1),
        ),
      ],
    );
    final comparison = TrajectoryComparison(
      baseline: baseline,
      outcomes: generated.outcomes,
      recommendedScenarioId: generated.outcomes.first.id,
    );
    await tester.pumpWidget(
      trajectoryScreenHarness(
        model: TrajectoryEngineModel(
          status: TrajectoryEngineStatus.ready,
          summary: fixture.summary,
          momentum: fixture.momentum,
          comparison: comparison,
          statusDetail: fixture.statusDetail,
          hasAvailableNetworkInterface: true,
        ),
      ),
    );
    await tester.pump();
    final scrollable = find.byType(Scrollable).first;
    await tapTrajectory(tester, find.text('Try a custom what-if'));
    await tapTrajectory(tester, find.text('Delay'));
    await tapTrajectory(tester, find.text('Compare over 7 days'));
    await tester.drag(find.byType(ListView), const Offset(0, 5000));
    await tester.pump();
    await tester.scrollUntilVisible(
      find.text('Selected custom delay result'),
      300,
      scrollable: scrollable,
    );
    expect(find.text('Selected custom delay result'), findsOneWidget);
    expect(find.text('Original complete result'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unobserved capacity is displayed as not scored', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final fixture = trajectoryTestEngineModel();
    final comparison = trajectoryTestComparison(
      baseline: trajectoryTestBaseline(
        availabilityOrigin: PredictiveEvidenceOrigin.unavailable,
      ),
    );
    await tester.pumpWidget(
      trajectoryScreenHarness(
        model: TrajectoryEngineModel(
          status: TrajectoryEngineStatus.partial,
          summary: fixture.summary,
          momentum: fixture.momentum,
          comparison: comparison,
          statusDetail: fixture.statusDetail,
          hasAvailableNetworkInterface: true,
        ),
      ),
    );
    await tester.pump();
    await tapTrajectory(tester, find.text('Full impact and evidence'));
    const String notShown =
        'Free-time risk score: not shown until your working hours are set.';
    await tester.scrollUntilVisible(
      find.textContaining(notShown),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining(notShown), findsOneWidget);
    expect(find.textContaining('Free-time risk score: 0 of 100'), findsNothing);
  });

  testWidgets(
    'empty plan with cached comparison withholds forecasts and restores on an active plan',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final active = trajectoryTestEngineModel();
      await tester.pumpWidget(trajectoryScreenHarness(model: active));
      await tester.pump();
      expect(find.text('If you keep going as you are'), findsOneWidget);

      await tester.pumpWidget(
        trajectoryScreenHarness(
          model: TrajectoryEngineModel(
            status: TrajectoryEngineStatus.empty,
            summary: active.summary,
            momentum: active.momentum,
            comparison: active.comparison,
            statusDetail:
                'Add a task with an estimate before simulating consequences.',
            hasAvailableNetworkInterface: true,
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Add a task to start'), findsOneWidget);
      expect(find.text('Add a task'), findsOneWidget);
      expect(find.text('If you keep going as you are'), findsNothing);
      expect(find.text('7 days'), findsNothing);
      expect(find.text('Keep going as you are'), findsNothing);
      expect(find.text('Energy you recorded'), findsOneWidget);
      expect(find.text('64%'), findsOneWidget);

      await tester.pumpWidget(trajectoryScreenHarness(model: active));
      await tester.pump();
      expect(find.text('If you keep going as you are'), findsOneWidget);
      expect(find.text('7 days'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('renders a concise forecast with progressive disclosure', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(trajectoryScreenHarness());
    await tester.pump();

    // A ready estimate needs no status card.
    expect(find.text('Estimate ready'), findsNothing);
    expect(find.text('If you keep going as you are'), findsOneWidget);
    expect(find.text('Recommended adjustment'), findsOneWidget);
    expect(find.text('7 days'), findsOneWidget);
    expect(find.text('30 days'), findsOneWidget);
    expect(find.text('90 days'), findsOneWidget);
    expect(find.text('What this estimate assumes'), findsOneWidget);
    expect(find.text('Exclude this forecast from monitoring'), findsOneWidget);
    expect(find.text('Track this option for monitoring'), findsOneWidget);
    // The disclosures start closed.
    expect(find.text('Status: provisional'), findsNothing);
    expect(find.text('Why this changes the estimate'), findsNothing);

    await tapTrajectory(tester, find.text('Full impact and evidence'));
    expect(find.text('Why this changes the estimate'), findsOneWidget);
    expect(find.text('Effect on your Schedule'), findsOneWidget);
    expect(find.text('Effect on progress'), findsOneWidget);
    expect(
      find.text(
        'Simulation only: no task, Schedule block, goal or progress reward is changed here.',
      ),
      findsOneWidget,
    );

    await tapTrajectory(tester, find.text('Forecast monitoring'));
    expect(find.text('Status: provisional'), findsOneWidget);
    await tapTrajectory(tester, find.text('What this is based on'));
    expect(
      find.byKey(const Key('future-outcomes-based-on-details')),
      findsOneWidget,
    );
    expect(find.textContaining('trajectory-fixture-r1'), findsNothing);
  });

  testWidgets('range choice selects the requested window', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(trajectoryScreenHarness());
    await tester.pump();

    await tester.tap(find.text('30 days'));
    await tester.pump();

    final ChoiceChip selected = tester.widget<ChoiceChip>(
      find.ancestor(
        of: find.text('30 days'),
        matching: find.byType(ChoiceChip),
      ),
    );
    expect(selected.selected, isTrue);
  });

  testWidgets('one tap records a local assumption correction', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final TrajectoryMemoryStore store = TrajectoryMemoryStore();
    final AccountStorageScope scope = AccountStorageScope.authenticated(
      'test-account',
    );
    final TrajectoryForecastLedgerRepository repository =
        TrajectoryForecastLedgerRepository(store: store, scope: scope);
    await tester.pumpWidget(
      trajectoryScreenHarness(
        repository: repository,
        model: trajectoryModelForScope(scope.v2Namespace!),
      ),
    );
    await tester.pump();

    await tapTrajectory(
      tester,
      find.text('Exclude this forecast from monitoring'),
    );
    await tester.pump(const Duration(milliseconds: 100));

    final List<TrajectoryForecastReceipt> receipts = await repository.load();
    expect(receipts, hasLength(1));
    expect(receipts.single.hasAssumptionCorrection, isTrue);
    expect(
      find.textContaining('Forecast excluded on this device'),
      findsOneWidget,
    );
  });

  testWidgets('error state does not render a false stable estimate', (
    WidgetTester tester,
  ) async {
    final TrajectoryEngineModel fixture = trajectoryTestEngineModel();
    await tester.pumpWidget(
      trajectoryScreenHarness(
        model: TrajectoryEngineModel(
          status: TrajectoryEngineStatus.error,
          summary: fixture.summary,
          momentum: fixture.momentum,
          statusDetail:
              'Trajectory evidence could not be reconciled. No future conclusion is currently valid.',
          hasAvailableNetworkInterface: true,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('The estimate could not be updated'), findsOneWidget);
    expect(
      find.text(
        'Your records could not be read for this estimate, so none is shown. Try again.',
      ),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('If you keep going as you are'), findsNothing);
    expect(find.text('What this is based on'), findsNothing);
  });

  testWidgets('cold-start state withholds personal forecasts', (
    WidgetTester tester,
  ) async {
    final TrajectoryEngineModel fixture = trajectoryTestEngineModel();
    await tester.pumpWidget(
      trajectoryScreenHarness(
        model: TrajectoryEngineModel(
          status: TrajectoryEngineStatus.learning,
          summary: fixture.summary,
          momentum: fixture.momentum,
          statusDetail:
              'Record 3 more task outcomes before ChronoSpark compares future paths. No personal forecast is shown yet.',
          hasAvailableNetworkInterface: true,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Learning your pattern'), findsOneWidget);
    expect(find.textContaining('Not enough history yet.'), findsOneWidget);
    expect(find.textContaining('Record 3 more task outcomes'), findsOneWidget);
    expect(find.text('If you keep going as you are'), findsNothing);
    expect(find.text('Options'), findsNothing);
    expect(find.text('Recommended adjustment'), findsNothing);
    expect(find.textContaining('No personal estimate'), findsOneWidget);
  });
}
