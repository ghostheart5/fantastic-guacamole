import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/domain/predictive/predictive_planning_contract.dart';
import 'package:fantastic_guacamole/domain/trajectory/trajectory_consequence_contract.dart';
import 'package:fantastic_guacamole/domain/trajectory/trajectory_forecast_receipt.dart';
import 'package:fantastic_guacamole/features/trajectory_engine/ui/trajectory_engine_screen.dart';
import 'package:fantastic_guacamole/l10n/chronospark_localizations.dart';
import 'package:fantastic_guacamole/state/providers/nexus_vitals_provider.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_consequence_provider.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_engine_model_provider.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_forecast_ledger_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/trajectory_test_fixture.dart';

/// Every workload figure on Future outcomes is for the selected range; Home
/// keeps the next-7-days value.
void main() {
  final String scope = AccountStorageScope.authenticated(
    'test-account',
  ).v2Namespace!;

  // 150 fixture minutes with 25 free minutes a day: the next 7 days need 86%
  // (high), but 30 days need 20% and 90 days 7%.
  TrajectoryBaseline tight(int days) => trajectoryTestBaseline(
    accountScope: scope,
    horizonDays: days,
    dailyFreeMinutes: 25,
  );

  test('the tight fixture really differs between 7 days and the range', () {
    expect(tight(30).pressure, 86);
    expect(tight(30).pressureInHorizon, 20);
    expect(tight(90).pressureInHorizon, 7);
  });

  test('an explicit 7-day pressure is also the range workload', () {
    final TrajectoryBaseline b = trajectoryTestBaseline(pressure: 58);
    expect(b.pressure, 58);
    expect(b.pressureInHorizon, 58);
  });

  for (final int days in const <int>[30, 90]) {
    testWidgets('at $days days every workload figure is for the range', (
      tester,
    ) async {
      final TrajectoryBaseline baseline = tight(days);
      final int range = baseline.pressureInHorizon;
      await _pump(tester, _model(baseline, days), days: days);

      // The keep-going card reads the range (20 or 7: light), never the
      // next 7 days' 86 (heavy).
      expect(find.text('Light, $range%'), findsOneWidget);
      expect(find.textContaining('Heavy'), findsNothing);
      expect(find.textContaining('86%'), findsNothing);

      // The selected option compares with keep going over the same range.
      final Finder keepGoing = find.textContaining('Keep going: $range%');
      await tester.scrollUntilVisible(
        keepGoing.first,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(keepGoing, findsOneWidget);
      expect(find.textContaining('Keep going: 86%'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  for (final String language in const <String>['en', 'es']) {
    for (final (
          int pressure,
          String en,
          String es,
          String bandEn,
          String bandEs,
        )
        in const <(int, String, String, String, String)>[
          (58, 'Busy, 58%', 'Intensa, 58%', 'Busy', 'Intensa'),
          (82, 'Heavy, 82%', 'Pesada, 82%', 'Heavy', 'Pesada'),
        ]) {
      testWidgets('workload band for $pressure in $language', (tester) async {
        final TrajectoryBaseline baseline = trajectoryTestBaseline(
          accountScope: scope,
          pressure: pressure,
        );
        await _pump(tester, _model(baseline, 7), locale: Locale(language));
        expect(
          find.text(language == 'es' ? es : en),
          findsOneWidget,
          reason: '$pressure',
        );
        expect(
          find.textContaining(language == 'es' ? bandEs : bandEn),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final int days in const <int>[30, 90]) {
    test('Home keeps the next-7-days value with a $days-day baseline', () {
      final ProviderContainer container = ProviderContainer(
        overrides: [
          trajectoryEngineModelProvider.overrideWithValue(
            _model(tight(days), days),
          ),
        ],
      );
      addTearDown(container.dispose);
      expect(container.read(nexusTrajectoryVitalsProvider).pressurePercent, 86);
    });
  }
}

TrajectoryEngineModel _model(TrajectoryBaseline baseline, int days) {
  final TrajectoryEngineModel fixture = trajectoryTestEngineModel();
  final TrajectoryComparison all = trajectoryTestComparison(
    horizonDays: days,
    baseline: baseline,
  );
  final TrajectoryScenarioOutcome keepGoing = all.outcomes.firstWhere(
    (TrajectoryScenarioOutcome o) => o.intervention.id == 'maintain',
  );
  return TrajectoryEngineModel(
    status: TrajectoryEngineStatus.ready,
    summary: fixture.summary,
    momentum: fixture.momentum,
    comparison: TrajectoryComparison(
      baseline: baseline,
      outcomes: <TrajectoryScenarioOutcome>[keepGoing],
      recommendedScenarioId: keepGoing.id,
    ),
    statusDetail: fixture.statusDetail,
    hasAvailableNetworkInterface: true,
  );
}

class _FixedHorizon extends TrajectoryHorizonController {
  _FixedHorizon(this.days);

  final int days;

  @override
  int build() => days;
}

Future<void> _pump(
  WidgetTester tester,
  TrajectoryEngineModel model, {
  int days = 7,
  Locale locale = const Locale('en'),
}) async {
  await tester.binding.setSurfaceSize(const Size(900, 2400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        trajectoryEngineModelProvider.overrideWithValue(model),
        trajectoryHorizonDaysProvider.overrideWith(() => _FixedHorizon(days)),
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
      child: MaterialApp(
        locale: locale,
        supportedLocales: const <Locale>[Locale('en'), Locale('es')],
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          ChronoSparkLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const TrajectoryEngineScreen(),
      ),
    ),
  );
  await _settle(tester);
}

Future<void> _settle(WidgetTester tester) async {
  // The background animates continuously; advance just the transitions.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump();
}
