import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/domain/predictive/predictive_planning_contract.dart';
import 'package:fantastic_guacamole/domain/trajectory/trajectory_consequence_contract.dart';
import 'package:fantastic_guacamole/domain/trajectory/trajectory_forecast_receipt.dart';
import 'package:fantastic_guacamole/features/trajectory_engine/ui/trajectory_engine_screen.dart';
import 'package:fantastic_guacamole/l10n/chronospark_localizations.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_engine_model_provider.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_forecast_ledger_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/trajectory_test_fixture.dart';

/// The forecast monitoring card says truthfully what recorded accuracy does.
void main() {
  const TrajectoryCalibrationSummary checked = TrajectoryCalibrationSummary(
    resolvedForecasts: 4,
    momentumMeanAbsoluteError: 12,
    pressureMeanAbsoluteError: 3,
    intervalCoverage: .5,
    state: PredictiveCalibrationState.monitored,
    earlierMethodForecasts: 2,
  );
  const TrajectoryCalibrationSummary onlyEarlier = TrajectoryCalibrationSummary(
    resolvedForecasts: 0,
    momentumMeanAbsoluteError: 0,
    pressureMeanAbsoluteError: 0,
    intervalCoverage: 0,
    state: PredictiveCalibrationState.provisional,
    earlierMethodForecasts: 3,
  );

  testWidgets('checked forecasts: ranges follow recorded accuracy (en)', (
    tester,
  ) async {
    await _pump(tester, checked, const Locale('en'));
    final Finder card = find.textContaining('4 resolved and monitored');
    expect(card, findsOneWidget);
    final String text = tester.widget<Text>(card).data!;
    expect(
      text,
      contains(
        'Ranges are widened or narrowed from recorded accuracy once at least '
        '3 forecasts have been checked. Forecasts used: 4. Kept from an '
        'earlier method but not used: 2.',
      ),
    );
    expect(text, isNot(contains('unchanged')));
    expect(find.textContaining('Coefficients and uncertainty'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('checked forecasts: ranges follow recorded accuracy (es)', (
    tester,
  ) async {
    await _pump(tester, checked, const Locale('es'));
    final Finder card = find.textContaining('4 resueltas y supervisadas');
    expect(card, findsOneWidget);
    final String text = tester.widget<Text>(card).data!;
    expect(
      text,
      contains(
        'Los rangos se amplían o se estrechan según la precisión registrada '
        'cuando hay al menos 3 previsiones comprobadas. Previsiones usadas: 4. '
        'Conservadas de un método anterior pero no usadas: 2.',
      ),
    );
    expect(text, isNot(contains('no cambian')));
    expect(
      find.textContaining('Los coeficientes y la incertidumbre'),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('no earlier-method sentence when there are none', (tester) async {
    await _pump(
      tester,
      const TrajectoryCalibrationSummary(
        resolvedForecasts: 1,
        momentumMeanAbsoluteError: 0,
        pressureMeanAbsoluteError: 0,
        intervalCoverage: 1,
        state: PredictiveCalibrationState.monitored,
      ),
      const Locale('en'),
    );
    final String text = tester
        .widget<Text>(find.textContaining('1 resolved and monitored'))
        .data!;
    expect(text, contains('Forecasts used: 1.'));
    expect(text, isNot(contains('earlier method')));
  });

  for (final (String language, String expected) in const <(String, String)>[
    ('en', 'Kept from an earlier method but not used: 3.'),
    ('es', 'Conservadas de un método anterior pero no usadas: 3.'),
  ]) {
    testWidgets('only earlier-method forecasts are counted ($language)', (
      tester,
    ) async {
      await _pump(tester, onlyEarlier, Locale(language));
      expect(find.textContaining(expected), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

TrajectoryEngineModel _model() {
  final TrajectoryEngineModel fixture = trajectoryTestEngineModel();
  final TrajectoryBaseline baseline = trajectoryTestBaseline(
    accountScope: AccountStorageScope.authenticated(
      'test-account',
    ).v2Namespace!,
  );
  final TrajectoryComparison all = trajectoryTestComparison(baseline: baseline);
  return TrajectoryEngineModel(
    status: TrajectoryEngineStatus.ready,
    summary: fixture.summary,
    momentum: fixture.momentum,
    comparison: all,
    statusDetail: fixture.statusDetail,
    hasAvailableNetworkInterface: true,
  );
}

Future<void> _pump(
  WidgetTester tester,
  TrajectoryCalibrationSummary summary,
  Locale locale,
) async {
  await tester.binding.setSurfaceSize(const Size(900, 2400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        trajectoryEngineModelProvider.overrideWithValue(_model()),
        trajectoryCalibrationSummaryProvider.overrideWithValue(
          AsyncValue<TrajectoryCalibrationSummary>.data(summary),
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
  final Finder details = find.text(
    locale.languageCode == 'es'
        ? 'Datos y detalles del modelo'
        : 'Evidence and model details',
  );
  await tester.scrollUntilVisible(
    details.hitTestable(),
    250,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(details.hitTestable());
  await _settle(tester);
}

Future<void> _settle(WidgetTester tester) async {
  // The background animates continuously; advance just the transitions.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump();
}
