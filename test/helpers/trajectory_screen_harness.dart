import 'package:fantastic_guacamole/data/repositories/trajectory_forecast_ledger_repository.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/domain/predictive/predictive_planning_contract.dart';
import 'package:fantastic_guacamole/domain/trajectory/trajectory_consequence_contract.dart';
import 'package:fantastic_guacamole/domain/trajectory/trajectory_forecast_receipt.dart';
import 'package:fantastic_guacamole/features/trajectory_engine/ui/trajectory_engine_screen.dart';
import 'package:fantastic_guacamole/l10n/chronospark_localizations.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_engine_model_provider.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_forecast_ledger_provider.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_habit_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'trajectory_test_fixture.dart';

/// The Future outcomes screen over a fixed model, as the split trajectory
/// screen tests (assumptions, states, Spanish copy) pump it.
Widget trajectoryScreenHarness({
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
    // Habit lines are covered by their own tests; here they are simply
    // ready with no habits.
    trajectoryHabitLinesProvider.overrideWithValue(
      TrajectoryHabitLines(
        status: TrajectoryHabitLinesStatus.ready,
        horizonDays: 7,
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

class TrajectoryMemoryStore implements SharedPrefsStore {
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

TrajectoryEngineModel trajectoryModelWithOutcomes(
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

TrajectoryEngineModel trajectoryModelForScope(String accountScope) {
  final TrajectoryEngineModel fixture = trajectoryTestEngineModel();
  return TrajectoryEngineModel(
    status: TrajectoryEngineStatus.ready,
    summary: fixture.summary,
    momentum: fixture.momentum,
    comparison: trajectoryTestComparison(
      baseline: trajectoryTestBaseline(accountScope: accountScope),
    ),
    statusDetail: fixture.statusDetail,
    hasAvailableNetworkInterface: fixture.hasAvailableNetworkInterface,
  );
}

Future<void> pumpTrajectoryTransition(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump();
}

/// Brings [finder] into view (scrolling down to build it when needed) and
/// taps it.
Future<void> tapTrajectory(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder.first,
      250,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(finder.first);
  await pumpTrajectoryTransition(tester);
  await tester.tap(finder.first);
  await pumpTrajectoryTransition(tester);
}
