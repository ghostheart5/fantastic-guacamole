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

  testWidgets('checked forecasts: ranges follow recorded accuracy (en)', (
    tester,
  ) async {
    await _pump(tester, checked, const Locale('en'));
    expect(find.text('MONITORED'), findsOneWidget);
    final Finder card = find.textContaining('4 resolved and monitored');
    expect(card, findsOneWidget);
    final String text = tester.widget<Text>(card).data!;
    expect(
      text,
      contains(
        'Accuracy here is about pace (momentum) only. Ranges are widened from '
        'recorded accuracy once at least 3 forecasts have been checked on 2 or '
        'more days, and narrowed only after checks on 5 or more days at least '
        '14 days apart. Forecasts used: 4. Kept from an earlier method but '
        'not used: 2.',
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
    expect(find.text('SUPERVISADO'), findsOneWidget);
    final Finder card = find.textContaining('4 resueltas y supervisadas');
    expect(card, findsOneWidget);
    final String text = tester.widget<Text>(card).data!;
    expect(
      text,
      contains(
        'La precisión aquí se refiere solo al ritmo (impulso). Los rangos se '
        'amplían según la precisión registrada cuando hay al menos 3 '
        'previsiones comprobadas en 2 o más días, y solo se estrechan tras '
        'comprobaciones en 5 o más días separados al menos 14 días. '
        'Previsiones usadas: 4. Conservadas de un método anterior pero no '
        'usadas: 2.',
      ),
    );
    expect(text, isNot(contains('no cambian')));
    expect(
      find.textContaining('Los coeficientes y la incertidumbre'),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  for (final (String language, String label, String expected)
      in const <(String, String, String)>[
        (
          'en',
          'PROVISIONAL',
          '2 resolved • momentum error 4.0 points • pressure error 1.0 points '
              '• interval coverage 100%. Accuracy here is about pace '
              '(momentum) only. Ranges stay as estimated until at least 3 '
              'forecasts have been checked on 2 or more days. Checked so '
              'far: 2.',
        ),
        (
          'es',
          'PROVISIONAL',
          '2 resueltas • error de impulso 4.0 puntos • error de presión 1.0 '
              'puntos • cobertura del intervalo 100%. La precisión aquí se '
              'refiere solo al ritmo (impulso). Los rangos se mantienen como '
              'se estimaron hasta que haya al menos 3 previsiones comprobadas '
              'en 2 o más días. Comprobadas hasta ahora: 2.',
        ),
      ]) {
    testWidgets('too few checks: label and text say provisional ($language)', (
      tester,
    ) async {
      await _pump(tester, tooFew, Locale(language));
      expect(find.text(label), findsOneWidget);
      expect(find.text('MONITORED'), findsNothing);
      expect(find.text('SUPERVISADO'), findsNothing);
      expect(find.text(expected), findsOneWidget);
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
