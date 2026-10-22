import 'package:fantastic_guacamole/state/models/trajectory_summary_view.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/repositories/trajectory_forecast_ledger_repository.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/domain/predictive/predictive_planning_contract.dart';
import 'package:fantastic_guacamole/domain/trajectory/trajectory_consequence_contract.dart';
import 'package:fantastic_guacamole/domain/trajectory/trajectory_forecast_receipt.dart';
import 'package:fantastic_guacamole/engine/trajectory/future_consequence_engine.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_engine_model_provider.dart';
import 'package:fantastic_guacamole/features/trajectory_engine/ui/trajectory_engine_screen.dart';
import 'package:fantastic_guacamole/l10n/chronospark_localizations.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_forecast_ledger_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/trajectory_test_fixture.dart';

void main() {
  group('Trajectory Engine integration', () {
    for (final language in ['en', 'es']) {
      testWidgets(
        'forecast assumptions are optional and complete in $language',
        (tester) async {
          await tester.binding.setSurfaceSize(const Size(900, 1800));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final store = _MemoryStore();
          final scope = AccountStorageScope.authenticated('test-account');
          final comparison = _modelForScope(scope.v2Namespace!).comparison!;
          final outcome = comparison.outcomes.firstWhere(
            (value) => value.intervention.id == 'planner',
          );
          final model = _modelWithOutcomes(comparison, [outcome]);
          final section = find.byKey(
            ValueKey<String>('trajectory-assumptions-${outcome.id}'),
          );
          final title = language == 'es'
              ? 'Supuestos de esta estimación'
              : 'What this estimate assumes';
          final notice = language == 'es'
              ? 'Explorar esta previsión no cambia tu plan guardado.'
              : 'Exploring this forecast does not change your saved plan.';
          await tester.pumpWidget(
            _harness(
              model: model,
              locale: Locale(language),
              repository: TrajectoryForecastLedgerRepository(
                store: store,
                scope: scope,
              ),
            ),
          );
          await _pumpForecastTransition(tester);
          await tester.scrollUntilVisible(
            find.text(title).hitTestable(),
            250,
            scrollable: find.byType(Scrollable).first,
          );
          await Scrollable.ensureVisible(
            tester.element(section),
            alignment: .5,
          );
          await _pumpForecastTransition(tester);
          expect(find.text(notice).hitTestable(), findsOneWidget);
          final bullets = find.descendant(
            of: section,
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is Text && (widget.data?.startsWith('• ') ?? false),
            ),
          );
          expect(bullets, findsNothing);
          await tester.tap(find.text(title).hitTestable());
          await _pumpForecastTransition(tester);
          expect(
            bullets,
            findsNWidgets(
              outcome.assumptions
                  .where((value) => value.trim().isNotEmpty)
                  .length,
            ),
          );
          await tester.ensureVisible(find.text(title));
          await _pumpForecastTransition(tester);
          await tester.tap(find.text(title).hitTestable());
          await _pumpForecastTransition(tester);
          expect(bullets, findsNothing);
          expect(store.writes, 0);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets('forecast assumptions keep shared-information warnings visible', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(900, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final comparison = trajectoryTestComparison(
        baseline: trajectoryTestBaseline(
          energyOrigin: PredictiveEvidenceOrigin.estimated,
          availabilityOrigin: PredictiveEvidenceOrigin.unavailable,
          personContextWarnings: ['Explicit boundary excludes task-polish.'],
        ),
      );
      await tester.pumpWidget(
        _harness(
          model: _modelWithOutcomes(comparison, [comparison.outcomes[1]]),
        ),
      );
      await _pumpForecastTransition(tester);
      expect(find.text('PARTIAL EVIDENCE'), findsOneWidget);
      expect(
        find.textContaining('energy is estimated; not observed'),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.text('What this estimate assumes').hitTestable(),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.text(
          'Review the assumptions for limits or missing details in information you shared.',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('Explicit boundary excludes task-polish.'),
        findsNothing,
      );
      await tester.tap(find.text('What this estimate assumes').hitTestable());
      await _pumpForecastTransition(tester);
      expect(
        find.textContaining('Explicit boundary excludes task-polish.'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Information you shared: Explicit boundary'),
        findsOneWidget,
      );
      expect(find.textContaining('Person Context constraint:'), findsNothing);
      expect(
        find.textContaining(
          'Capacity-based risk and goal completion dates are withheld.',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'forecast assumptions reset when the selected outcome changes',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(900, 1800));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final comparison = trajectoryTestComparison();
        final first = comparison.outcomes.firstWhere(
          (value) => value.intervention.id == 'planner',
        );
        final second = comparison.outcomes.firstWhere(
          (value) => value.intervention.id == 'maintain',
        );
        await tester.pumpWidget(
          _harness(model: _modelWithOutcomes(comparison, [first])),
        );
        await _pumpForecastTransition(tester);
        await tester.scrollUntilVisible(
          find.text('What this estimate assumes').hitTestable(),
          250,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text('What this estimate assumes').hitTestable());
        await _pumpForecastTransition(tester);
        expect(
          find.textContaining('The protected block is attempted.'),
          findsOneWidget,
        );
        await tester.pumpWidget(
          _harness(model: _modelWithOutcomes(comparison, [second])),
        );
        await _pumpForecastTransition(tester);
        expect(
          find.textContaining('The protected block is attempted.'),
          findsNothing,
        );
        final section = find.byKey(
          ValueKey<String>('trajectory-assumptions-${second.id}'),
        );
        final expansion = tester.widget<ExpansionTile>(
          find.descendant(of: section, matching: find.byType(ExpansionTile)),
        );
        expect(expansion.initiallyExpanded, isFalse);
        expect(
          find.descendant(
            of: section,
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is Text && (widget.data?.startsWith('• ') ?? false),
            ),
          ),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('forecast assumptions fit narrow Spanish enlarged text', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _harness(locale: const Locale('es'), textScale: 2),
      );
      await _pumpForecastTransition(tester);
      final title = find.text('Supuestos de esta estimación');
      await tester.scrollUntilVisible(
        title.hitTestable(),
        180,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 40,
      );
      await tester.ensureVisible(title);
      await _pumpForecastTransition(tester);
      final bounds = tester.getRect(title);
      expect(bounds.left, greaterThanOrEqualTo(0));
      expect(bounds.right, lessThanOrEqualTo(320));
      expect(title.hitTestable(), findsOneWidget);
      await tester.tap(title.hitTestable());
      await _pumpForecastTransition(tester);
      expect(
        find.textContaining('Esta estimación cambia solo'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

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
              _harness(
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
            // Forecast scores use their actual 0–100 scale, not percent probability.
            final scorePrefix = language == 'en' ? 'Momentum' : 'Impulso';
            expect(
              find.textContaining(RegExp('$scorePrefix \\d+–\\d+/100')),
              findsWidgets,
            );
            expect(
              find.textContaining(RegExp('$scorePrefix \\d+–\\d+%')),
              findsNothing,
            );
            final section = language == 'en'
                ? 'Task predictions'
                : 'Predicciones de tareas';
            final scrollable = find.byType(Scrollable).first;
            await tester.scrollUntilVisible(
              find.text(section).hitTestable(),
              300,
              scrollable: scrollable,
            );
            await tester.tap(find.text(section).hitTestable());
            await tester.pump(const Duration(seconds: 1));
            final lead = find.text(
              samples == 0
                  ? language == 'en'
                        ? 'No recorded task outcomes are available for this estimate.'
                        : 'No hay resultados de tareas registrados disponibles para esta estimación.'
                  : pooled
                  ? language == 'en'
                        ? 'Across 5 recorded task outcomes — no history for this task.'
                        : 'Basado en 5 resultados de otras tareas; sin historial para esta tarea.'
                  : language == 'en'
                  ? 'Based on 5 recorded task outcomes.'
                  : 'Basado en 5 resultados de tareas registrados.',
            );
            await tester.scrollUntilVisible(lead, 150, scrollable: scrollable);
            expect(lead, findsOneWidget);
            // Preserve the separate probability estimate and statistical interval.
            final estimate = find.textContaining(
              samples == 0
                  ? language == 'en'
                        ? '50% smoothed completion estimate • 0–100% interval • 0 outcomes'
                        : '50% de finalización estimada • intervalo 0–100% • 0 resultados'
                  : language == 'en'
                  ? '86% smoothed completion estimate • 67–100% interval • 5 outcomes'
                  : '86% de finalización estimada • intervalo 67–100% • 5 resultados',
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

    testWidgets(
      'composing delay selects the revision-qualified delay outcome',
      (tester) async {
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
          _harness(
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
        await tester.scrollUntilVisible(
          find.text('Try a custom what-if').hitTestable(),
          300,
          scrollable: scrollable,
        );
        await tester.tap(find.text('Try a custom what-if').hitTestable());
        await tester.pump(const Duration(seconds: 1));
        await tester.scrollUntilVisible(
          find.text('Delay').hitTestable(),
          300,
          scrollable: scrollable,
        );
        await tester.tap(find.text('Delay').hitTestable());
        await tester.pump(const Duration(milliseconds: 500));
        await tester.scrollUntilVisible(
          find.text('Compare 7-day path').hitTestable(),
          300,
          scrollable: scrollable,
        );
        await tester.tap(find.text('Compare 7-day path').hitTestable());
        await tester.pump();
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
      },
    );

    testWidgets('unobserved capacity is displayed as not scored', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(900, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final fixture = trajectoryTestEngineModel();
      final comparison = trajectoryTestComparison(
        baseline: trajectoryTestBaseline(
          availabilityOrigin: PredictiveEvidenceOrigin.unavailable,
        ),
      );
      await tester.pumpWidget(
        _harness(
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
      final scrollable = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(
        find.text('Full impact and evidence'),
        300,
        scrollable: scrollable,
      );
      await tester.tap(find.text('Full impact and evidence'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.scrollUntilVisible(
        find.textContaining('Capacity overload: not scored.'),
        300,
        scrollable: scrollable,
      );
      expect(
        find.textContaining('Capacity overload: not scored.'),
        findsOneWidget,
      );
      expect(find.textContaining('Capacity overload: 0%'), findsNothing);
    });

    testWidgets('localizes the observed Spanish overview', (tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_harness(locale: const Locale('es')));
      await tester.pump();

      expect(find.text('DIRECCIÓN ACTUAL'), findsOneWidget);
      expect(find.text('Requiere atención'), findsOneWidget);
      expect(find.text('CARGA MODELADA'), findsOneWidget);
      expect(find.text('IMPULSO'), findsWidgets);
      expect(find.text('ENERGÍA'), findsWidgets);
      expect(find.textContaining('Límite de evidencia:'), findsOneWidget);
      await tester.drag(find.byType(ListView), const Offset(0, -1100));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('RAMAS FUTURAS'), findsWidgets);
      expect(
        find.text(
          'Selecciona un camino para revisar sus consecuencias proyectadas.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('CAMINO MODELADO'), findsWidgets);
      expect(find.text('Compare options'), findsNothing);
      expect(find.textContaining('MODELED PATH'), findsNothing);
      expect(find.text('Supuestos de esta estimación'), findsWidgets);
      expect(find.text('What this estimate assumes'), findsNothing);
    });

    testWidgets('localizes the fixed custom-removal description in Spanish', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(900, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final TrajectoryEngineModel fixture = trajectoryTestEngineModel();
      final TrajectoryBaseline baseline = trajectoryTestBaseline();
      final TrajectoryComparison
      comparison = const FutureConsequenceEngine().compare(
        baseline: baseline,
        generatedAt: trajectoryFixtureNow,
        interventions: <TrajectoryIntervention>[
          TrajectoryIntervention(
            id: 'custom-remove-task-polish-7',
            type: TrajectoryInterventionType.reduceScope,
            title: 'My scenario: remove Polish optional copy',
            horizon: const Duration(days: 7),
            description:
                'Remove this commitment from the active capacity window and compare the resulting tradeoff.',
            subjectId: 'task-polish',
            displacedSubjectIds: <String>['task-polish'],
          ),
        ],
      );
      expect(
        comparison.outcomes.single.progression.summary,
        'No Activity reward is projected from this intervention alone.',
      );
      await tester.pumpWidget(
        _harness(
          locale: const Locale('es'),
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

      const String localized =
          'Quitar este compromiso de la ventana de capacidad activa y comparar la compensación resultante.';
      await tester.scrollUntilVisible(
        find.text(localized),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(localized), findsOneWidget);
      expect(find.textContaining('Quitar this commitment'), findsNothing);
      expect(find.textContaining('Remove this commitment'), findsNothing);
      // Render the real engine-produced no-reward result in the expanded panel;
      // a matching dictionary key alone would not catch producer drift.
      await tester.scrollUntilVisible(
        find.text('Impacto completo y datos'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Impacto completo y datos'));
      await tester.pump(const Duration(milliseconds: 300));
      const noReward =
          'Esta intervención por sí sola no proyecta una recompensa de progreso.';
      await tester.scrollUntilVisible(
        find.text(noReward),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(noReward), findsOneWidget);
      expect(
        find.text(comparison.outcomes.single.progression.summary),
        findsNothing,
      );
    });

    testWidgets('localizes partial evidence details and evidence origins', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(900, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final TrajectoryEngineModel fixture = trajectoryTestEngineModel();
      final TrajectoryComparison comparison = trajectoryTestComparison(
        baseline: trajectoryTestBaseline(
          energyOrigin: PredictiveEvidenceOrigin.estimated,
          availabilityOrigin: PredictiveEvidenceOrigin.unavailable,
        ),
      );
      await tester.pumpWidget(
        _harness(
          locale: const Locale('es'),
          model: TrajectoryEngineModel(
            status: TrajectoryEngineStatus.partial,
            summary: fixture.summary,
            momentum: fixture.momentum,
            comparison: comparison,
            statusDetail:
                'Future paths are conditional models. Working availability is not configured, so capacity risk, goal dates, and best-fit claims are withheld.',
            hasAvailableNetworkInterface: true,
          ),
        ),
      );
      await tester.pump();

      expect(
        find.textContaining('Los caminos futuros son modelos condicionales'),
        findsOneWidget,
      );
      expect(find.textContaining('Future paths are conditional'), findsNothing);
      expect(
        find.textContaining('disponibilidad está sin datos observados'),
        findsOneWidget,
      );
      expect(find.textContaining('unavailable'), findsNothing);
    });

    testWidgets(
      'empty plan with cached comparison withholds forecasts and restores on an active plan',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(900, 1800));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final active = trajectoryTestEngineModel();
        await tester.pumpWidget(_harness(model: active));
        await tester.pump();
        expect(find.text('CURRENT DIRECTION'), findsOneWidget);

        await tester.pumpWidget(
          _harness(
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
        expect(find.text('EVIDENCE NEEDED'), findsOneWidget);
        expect(find.text('CURRENT DIRECTION'), findsNothing);
        expect(find.text('MOMENTUM'), findsNothing);
        expect(find.text('7 DAYS'), findsNothing);
        expect(find.text('Maintain current course'), findsNothing);
        expect(find.text('ENERGY'), findsOneWidget);
        expect(find.text('64%'), findsOneWidget);

        await tester.pumpWidget(_harness(model: active));
        await tester.pump();
        expect(find.text('CURRENT DIRECTION'), findsOneWidget);
        expect(find.text('MOMENTUM'), findsWidgets);
        expect(find.text('7 DAYS'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('renders a concise forecast with progressive disclosure', (
      WidgetTester tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(900, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_harness());
      await tester.pump();

      expect(find.text('BASELINE READY'), findsOneWidget);
      expect(find.text('CURRENT DIRECTION'), findsOneWidget);
      expect(find.text('RECOMMENDED ADJUSTMENT'), findsOneWidget);
      expect(find.text('Compare a path'), findsNothing);
      expect(find.text('BEST NEXT ADJUSTMENT'), findsNothing);
      expect(find.text('7 DAYS'), findsOneWidget);
      expect(find.text('30 DAYS'), findsOneWidget);
      expect(find.text('90 DAYS'), findsOneWidget);
      expect(find.text('CURRENT PLAN ESTIMATES'), findsNothing);
      expect(find.text('FORECAST MONITORING'), findsNothing);
      expect(find.text('What this estimate assumes'), findsWidgets);
      expect(
        find.text('Exclude this forecast from monitoring'),
        findsOneWidget,
      );

      await tester.scrollUntilVisible(
        find.text('Full impact and evidence'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Full impact and evidence'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.scrollUntilVisible(
        find.text('WHY THIS CHANGES THE FUTURE'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('WHY THIS CHANGES THE FUTURE'), findsOneWidget);
      expect(find.text('SCHEDULE IMPACT'), findsOneWidget);
      expect(find.text('ACTIVITY IMPACT'), findsOneWidget);
      expect(
        find.text(
          'SIMULATION ONLY — no task, Schedule block, goal, or Activity reward is changed here.',
        ),
        findsOneWidget,
      );
      expect(find.text('Track this path for monitoring'), findsOneWidget);
      await tester.tap(find.text('Full impact and evidence'));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.scrollUntilVisible(
        find.text('Evidence and model details'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Evidence and model details'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('CURRENT PLAN ESTIMATES'), findsOneWidget);
      expect(find.textContaining('trajectory-fixture-r1'), findsNothing);
      expect(find.text('FORECAST MONITORING'), findsOneWidget);
      expect(find.text('PROVISIONAL'), findsOneWidget);
    });

    testWidgets('horizon control selects the requested future window', (
      WidgetTester tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(900, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_harness());
      await tester.pump();

      await tester.tap(find.text('30 DAYS'));
      await tester.pump();

      final ChoiceChip selected = tester.widget<ChoiceChip>(
        find.ancestor(
          of: find.text('30 DAYS'),
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
      final _MemoryStore store = _MemoryStore();
      final AccountStorageScope scope = AccountStorageScope.authenticated(
        'test-account',
      );
      final TrajectoryForecastLedgerRepository repository =
          TrajectoryForecastLedgerRepository(store: store, scope: scope);
      await tester.pumpWidget(
        _harness(
          repository: repository,
          model: _modelForScope(scope.v2Namespace!),
        ),
      );
      await tester.pump();

      await tester.scrollUntilVisible(
        find.text('Exclude this forecast from monitoring'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Exclude this forecast from monitoring'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final List<TrajectoryForecastReceipt> receipts = await repository.load();
      expect(receipts, hasLength(1));
      expect(receipts.single.hasAssumptionCorrection, isTrue);
      expect(find.textContaining('Forecast excluded locally'), findsOneWidget);
    });

    testWidgets('error state does not render a false stable trajectory', (
      WidgetTester tester,
    ) async {
      final TrajectoryEngineModel fixture = trajectoryTestEngineModel();
      await tester.pumpWidget(
        _harness(
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

      expect(find.text('RECALCULATION NEEDED'), findsOneWidget);
      expect(find.text('CURRENT DIRECTION'), findsNothing);
      expect(find.text('CURRENT PLAN ESTIMATES'), findsNothing);
      expect(find.textContaining('No future conclusion'), findsOneWidget);
    });

    testWidgets('cold-start state withholds personal forecasts', (
      WidgetTester tester,
    ) async {
      final TrajectoryEngineModel fixture = trajectoryTestEngineModel();
      await tester.pumpWidget(
        _harness(
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

      expect(find.text('LEARNING YOUR PATTERN'), findsOneWidget);
      expect(find.text('CURRENT DIRECTION'), findsNothing);
      expect(find.text('MODELED PATH 1'), findsNothing);
      expect(find.text('RECOMMENDED ADJUSTMENT'), findsNothing);
      expect(find.textContaining('No personal forecast'), findsOneWidget);
    });
  });
}

Widget _harness({
  TrajectoryEngineModel? model,
  TrajectoryForecastLedgerRepository? repository,
  Locale locale = const Locale('en'),
  double textScale = 1,
}) => ProviderScope(
  overrides: [
    trajectoryEngineModelProvider.overrideWithValue(
      model ?? trajectoryTestEngineModel(),
    ),
    trajectoryCalibrationSummaryProvider.overrideWithValue(
      const AsyncValue<TrajectoryCalibrationSummary>.data(
        TrajectoryCalibrationSummary(
          resolvedForecasts: 0,
          momentumMeanAbsoluteError: 0,
          pressureMeanAbsoluteError: 0,
          intervalCoverage: 0,
          state: PredictiveCalibrationState.provisional,
        ),
      ),
    ),
    if (repository != null)
      trajectoryForecastLedgerRepositoryProvider.overrideWithValue(repository),
  ],
  child: MaterialApp(
    locale: locale,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    supportedLocales: const <Locale>[Locale('en'), Locale('es')],
    localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
      ChronoSparkLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: const TrajectoryEngineScreen(),
  ),
);

class _MemoryStore implements SharedPrefsStore {
  final Map<String, String> values = <String, String>{};
  int writes = 0;

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
    writes++;
    values[key] = value;
  }
}

TrajectoryEngineModel _modelWithOutcomes(
  TrajectoryComparison comparison,
  List<TrajectoryScenarioOutcome> outcomes,
) {
  final fixture = trajectoryTestEngineModel();
  return TrajectoryEngineModel(
    status: TrajectoryEngineStatus.partial,
    summary: fixture.summary,
    momentum: fixture.momentum,
    comparison: TrajectoryComparison(
      baseline: comparison.baseline,
      outcomes: outcomes,
      recommendedScenarioId: outcomes.first.id,
    ),
    statusDetail: fixture.statusDetail,
    hasAvailableNetworkInterface: true,
  );
}

TrajectoryEngineModel _modelForScope(String accountScope) {
  final TrajectoryEngineModel fixture = trajectoryTestEngineModel();
  final TrajectoryBaseline baseline = trajectoryTestBaseline();
  final TrajectoryBaseline scopedBaseline = TrajectoryBaseline(
    accountScope: accountScope,
    revision: baseline.revision,
    observedAt: baseline.observedAt,
    evidenceWindow: baseline.evidenceWindow,
    momentum: baseline.momentum,
    pressure: baseline.pressure,
    energy: baseline.energy,
    completedInWindow: baseline.completedInWindow,
    deferredInWindow: baseline.deferredInWindow,
    observationCount: baseline.observationCount,
    availableMinutes: baseline.availableMinutes,
    occupiedMinutes: baseline.occupiedMinutes,
    unscheduledMinutes: baseline.unscheduledMinutes,
    tasks: baseline.tasks,
    goals: baseline.goals,
    blocks: baseline.blocks,
    timelineSignals: baseline.timelineSignals,
    progression: baseline.progression,
    confidence: baseline.confidence,
    sourceRevisions: baseline.sourceRevisions,
    energyOrigin: baseline.energyOrigin,
    availabilityOrigin: baseline.availabilityOrigin,
  );
  return TrajectoryEngineModel(
    status: TrajectoryEngineStatus.ready,
    summary: fixture.summary,
    momentum: fixture.momentum,
    comparison: trajectoryTestComparison(baseline: scopedBaseline),
    statusDetail: fixture.statusDetail,
    hasAvailableNetworkInterface: fixture.hasAvailableNetworkInterface,
  );
}

Future<void> _pumpForecastTransition(WidgetTester tester) async {
  // The space artwork animates continuously; advance just the disclosure.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump();
}
