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
  // Four forecasts checked on four days over three weeks: the rule widens.
  const TrajectoryCalibrationSummary checked = TrajectoryCalibrationSummary(
    resolvedForecasts: 4,
    momentumMeanAbsoluteError: 12,
    pressureMeanAbsoluteError: 3,
    intervalCoverage: .5,
    state: PredictiveCalibrationState.monitored,
    earlierMethodForecasts: 2,
    checkDays: 4,
    checkSpanDays: 21,
  );
  // Two checked forecasts: too few, the ranges stay as estimated.
  const TrajectoryCalibrationSummary tooFew = TrajectoryCalibrationSummary(
    resolvedForecasts: 2,
    momentumMeanAbsoluteError: 4,
    pressureMeanAbsoluteError: 1,
    intervalCoverage: 1,
    state: PredictiveCalibrationState.monitored,
    checkDays: 2,
    checkSpanDays: 7,
  );
  const TrajectoryCalibrationSummary onlyEarlier = TrajectoryCalibrationSummary(
    resolvedForecasts: 0,
    momentumMeanAbsoluteError: 0,
    pressureMeanAbsoluteError: 0,
    intervalCoverage: 0,
    state: PredictiveCalibrationState.provisional,
    earlierMethodForecasts: 3,
  );

  // Forecasts fell due but none could be checked (found too late, or from
  // an earlier method): the card must not say none has reached its end date.
  const TrajectoryCalibrationSummary setAsideOnly =
      TrajectoryCalibrationSummary(
        resolvedForecasts: 0,
        momentumMeanAbsoluteError: 0,
        pressureMeanAbsoluteError: 0,
        intervalCoverage: 0,
        state: PredictiveCalibrationState.provisional,
        missedForecasts: 2,
      );
  const TrajectoryCalibrationSummary nothingDue = TrajectoryCalibrationSummary(
    resolvedForecasts: 0,
    momentumMeanAbsoluteError: 0,
    pressureMeanAbsoluteError: 0,
    intervalCoverage: 0,
    state: PredictiveCalibrationState.provisional,
  );
  for (final (String language, String unchecked, String missed, String early)
      in const <(String, String, String, String)>[
        (
          'en',
          'No recorded forecast has been checked against your records yet, so '
              'the ranges stay as estimated.',
          'Due too long ago to be checked, not used: 2.',
          'No recorded forecast has reached its end date yet, so the ranges '
              'stay as estimated.',
        ),
        (
          'es',
          'Todavía no se ha comprobado ninguna previsión registrada con tus '
              'registros, así que los rangos se mantienen como se estimaron.',
          'Vencidas hace demasiado para comprobarlas, no usadas: 2.',
          'Ninguna previsión registrada ha llegado aún a su fecha final, así '
              'que los rangos se mantienen como se estimaron.',
        ),
      ]) {
    testWidgets('forecasts set aside unchecked: a true sentence and their '
        'count ($language)', (tester) async {
      await _pump(tester, setAsideOnly, Locale(language));
      expect(find.text(unchecked), findsOneWidget);
      expect(find.text(missed), findsOneWidget);
      expect(find.text(early), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('nothing due yet keeps its sentence ($language)', (
      tester,
    ) async {
      await _pump(tester, nothingDue, Locale(language));
      expect(find.text(early), findsOneWidget);
      expect(find.text(unchecked), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('checked forecasts: ranges follow recorded accuracy (en)', (
    tester,
  ) async {
    await _pump(tester, checked, const Locale('en'));
    expect(find.text('Status: monitored'), findsOneWidget);
    expect(
      find.text(
        '4 forecasts checked • average pace error 12.0 points • average '
        'workload error 3.0 '
        'points • 50% inside their range.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'The share inside the range uses pace only and is averaged over the days '
        'forecasts were checked.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Ranges are widened from recorded accuracy once at least 3 forecasts '
        'have been checked on 2 or more days, and narrowed only after checks '
        'on 5 or more days spread over at least 14 days. Forecasts used: 4.',
      ),
      findsOneWidget,
    );
    expect(
      find.text('Kept from an earlier method but not used: 2.'),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('future-outcomes-monitoring-details')),
        matching: find.textContaining('unchanged'),
      ),
      findsNothing,
    );
    expect(find.textContaining('Coefficients and uncertainty'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('checked forecasts: ranges follow recorded accuracy (es)', (
    tester,
  ) async {
    await _pump(tester, checked, const Locale('es'));
    expect(find.text('Estado: supervisado'), findsOneWidget);
    expect(
      find.text(
        '4 previsiones comprobadas • error medio de ritmo 12.0 puntos • error medio de '
        'carga 3.0 puntos • 50% dentro de su rango.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'La parte dentro del rango usa solo el ritmo y se promedia por los '
        'días en que se comprobaron las previsiones.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Los rangos se amplían según la precisión registrada cuando hay al '
        'menos 3 previsiones comprobadas en 2 o más días, y solo se estrechan '
        'tras comprobaciones en 5 o más días repartidos en al menos 14 días. '
        'Previsiones usadas: 4.',
      ),
      findsOneWidget,
    );
    expect(
      find.text('Conservadas de un método anterior pero no usadas: 2.'),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('future-outcomes-monitoring-details')),
        matching: find.textContaining('no cambian'),
      ),
      findsNothing,
    );
    expect(
      find.textContaining('Los coeficientes y la incertidumbre'),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  for (final (String language, String label, String figures, String rule)
      in const <(String, String, String, String)>[
        (
          'en',
          'Status: provisional',
          '2 forecasts checked • average pace error 4.0 points • average '
              'workload error 1.0 '
              'points • 100% inside their range.',
          'Ranges stay as estimated until at least 3 forecasts have been '
              'checked on 2 or more days. Checked so far: 2.',
        ),
        (
          'es',
          'Estado: provisional',
          '2 previsiones comprobadas • error medio de ritmo 4.0 puntos • error medio de '
              'carga 1.0 puntos • 100% dentro de su rango.',
          'Los rangos se mantienen como se estimaron hasta que haya al menos '
              '3 previsiones comprobadas en 2 o más días. Comprobadas hasta '
              'ahora: 2.',
        ),
      ]) {
    testWidgets('too few checks: label and text say provisional ($language)', (
      tester,
    ) async {
      await _pump(tester, tooFew, Locale(language));
      expect(find.text(label), findsOneWidget);
      expect(find.text('Status: monitored'), findsNothing);
      expect(find.text('Estado: supervisado'), findsNothing);
      expect(find.text(figures), findsOneWidget);
      expect(find.text(rule), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
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
        ? 'Seguimiento de previsiones'
        : 'Forecast monitoring',
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
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump();
}
