import 'package:fantastic_guacamole/domain/predictive/predictive_planning_contract.dart';
import 'package:fantastic_guacamole/domain/trajectory/trajectory_forecast_receipt.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_engine_model_provider.dart';
import 'package:fantastic_guacamole/features/trajectory_engine/ui/trajectory_engine_screen.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_forecast_ledger_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/trajectory_test_fixture.dart';

void main() {
  group('Trajectory Engine integration', () {
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
      expect(find.text('FORECAST CALIBRATION'), findsNothing);

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
      expect(find.text('Track this path for calibration'), findsOneWidget);
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
      expect(find.text('FORECAST CALIBRATION'), findsOneWidget);
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
            isOnline: true,
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
            isOnline: true,
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

Widget _harness({TrajectoryEngineModel? model}) => ProviderScope(
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
  ],
  child: const MaterialApp(home: TrajectoryEngineScreen()),
);
