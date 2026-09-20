import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/repositories/trajectory_forecast_ledger_repository.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/domain/predictive/predictive_planning_contract.dart';
import 'package:fantastic_guacamole/domain/trajectory/trajectory_consequence_contract.dart';
import 'package:fantastic_guacamole/domain/trajectory/trajectory_forecast_receipt.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_engine_model_provider.dart';
import 'package:fantastic_guacamole/features/trajectory_engine/ui/trajectory_engine_screen.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_forecast_ledger_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/trajectory_test_fixture.dart';

void main() {
  group('Trajectory Engine integration', () {
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
      expect(find.text('CURRENT TRAJECTORY BASELINE'), findsNothing);
      expect(find.text('FORECAST MONITORING'), findsNothing);
      expect(find.text('ASSUMPTIONS FOR THIS RESULT'), findsWidgets);
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
      expect(find.text('TIMELINE IMPACT'), findsOneWidget);
      expect(find.text('PROGRESSION IMPACT'), findsOneWidget);
      expect(
        find.text(
          'SIMULATION ONLY — no task, Timeline block, goal, or Progression reward is changed here.',
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
      expect(find.text('CURRENT TRAJECTORY BASELINE'), findsOneWidget);
      expect(find.textContaining('trajectory-fixture-r1'), findsWidgets);
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
      expect(find.text('CURRENT TRAJECTORY BASELINE'), findsNothing);
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
    supportedLocales: const <Locale>[Locale('en'), Locale('es')],
    localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: const TrajectoryEngineScreen(),
  ),
);

class _MemoryStore implements SharedPrefsStore {
  final Map<String, String> values = <String, String>{};

  @override
  Future<void> clear() async => values.clear();
  @override
  Future<void> delete(String key) async => values.remove(key);
  @override
  Future<void> init() async {}
  @override
  String? load(String key) => values[key];
  @override
  Future<void> save(String key, String value) async => values[key] = value;
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
