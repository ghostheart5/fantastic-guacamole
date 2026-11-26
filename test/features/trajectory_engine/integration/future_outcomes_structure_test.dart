import 'package:fantastic_guacamole/domain/predictive/predictive_planning_contract.dart';
import 'package:fantastic_guacamole/domain/trajectory/trajectory_consequence_contract.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_consequence_provider.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_engine_model_provider.dart';
import 'package:fantastic_guacamole/ui/layout/animated_system_background.dart';
import 'package:fantastic_guacamole/ui/navigation/insights_destination_switch.dart';
import 'package:fantastic_guacamole/ui/system/temporal_glass.dart';
import 'package:fantastic_guacamole/ui/widgets/plain/plain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/future_outcomes_harness.dart';
import '../../../helpers/trajectory_test_fixture.dart';

/// Future outcomes on the plain kit: structure, the selected range, labels
/// on every figure, and no prediction worded as certain.
void main() {
  final RegExp certainEn = RegExp(
    r'\b(will|guaranteed?|definitely|certain(ly)?)\b',
    caseSensitive: false,
  );
  final RegExp certainEs = RegExp(
    r'\b(seguro|garantizad\w*|sin duda|con certeza)\b',
    caseSensitive: false,
  );

  testWidgets('the ready screen is built on PlainScreen, not the old frame', (
    tester,
  ) async {
    await pumpFutureOutcomes(tester);
    expect(find.byType(PlainScreen), findsOneWidget);
    expect(find.byType(AnimatedSystemBackground), findsNothing);
    expect(find.byType(TemporalGlassSurface), findsNothing);
    expect(find.byType(TemporalScreenHeader), findsNothing);
    await openAllDisclosures(tester);
    expect(find.byType(TemporalGlassSurface), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('order: header, switch, estimates line, range, keep going, '
      'options, selected option, disclosures', (tester) async {
    await pumpFutureOutcomes(tester, size: const Size(900, 6000));
    double top(Finder f) => tester.getTopLeft(f.first).dy;
    final List<Finder> order = <Finder>[
      find.descendant(
        of: find.byType(PlainHeader),
        matching: find.text('Insights'),
      ),
      find.byKey(InsightsDestinationSwitch.switchKey),
      find.text('These are estimates, not promises.'),
      find.text(
        'Since this update, the time range changes the estimate and workload '
        'uses your free time and task dates.',
      ),
      find.text('7 days'),
      find.text('If you keep going as you are'),
      find.text('Options'),
      find.text('Selected option'),
      find.text('What this is based on'),
      find.text('Forecast monitoring'),
    ];
    for (int i = 1; i < order.length; i++) {
      expect(
        top(order[i]),
        greaterThan(top(order[i - 1])),
        reason: '${order[i]} should follow ${order[i - 1]}',
      );
    }
    // Capitals-only labels are gone.
    for (final String text in futureOutcomesTexts(tester)) {
      final String letters = text.replaceAll(RegExp(r'[^A-Za-zÁÉÍÓÚÑ]'), '');
      expect(
        letters.length > 3 && letters == letters.toUpperCase(),
        isFalse,
        reason: text,
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('switching 7 → 90 days changes workload and expected '
      'completions; every figure is for the selected range', (tester) async {
    final ProviderContainer container = await pumpFutureOutcomes(tester);
    final TrajectoryBaseline seven = futureOutcomesBaseline(days: 7);
    final TrajectoryBaseline ninety = futureOutcomesBaseline(days: 90);
    expect(seven.pressureInHorizon, isNot(ninety.pressureInHorizon));
    expect(
      seven.expectedCompletionsInHorizon.mid,
      isNot(ninety.expectedCompletionsInHorizon.mid),
    );

    String rowText(Key key) => tester
        .widgetList<Text>(
          find.descendant(of: find.byKey(key), matching: find.byType(Text)),
        )
        .map((Text t) => t.data ?? '')
        .join(' | ');

    expect(
      rowText(const Key('keep-going-workload')),
      contains('Light, ${seven.pressureInHorizon}%'),
    );
    expect(
      rowText(const Key('keep-going-tasks')),
      contains('${seven.tasksInHorizon}'),
    );
    expect(
      rowText(const Key('keep-going-finish')),
      contains(
        'about ${seven.expectedCompletionsInHorizon.mid} of '
        '${seven.tasksInHorizon}',
      ),
    );
    expect(find.text('Over the next 7 days.'), findsOneWidget);

    await tapFutureOutcomes(tester, find.text('90 days'));
    expect(container.read(trajectoryHorizonDaysProvider), 90);
    final String workload90 = rowText(const Key('keep-going-workload'));
    expect(workload90, contains('Light, ${ninety.pressureInHorizon}%'));
    expect(workload90, isNot(contains('${seven.pressureInHorizon}%')));
    expect(
      rowText(const Key('keep-going-finish')),
      contains(
        'about ${ninety.expectedCompletionsInHorizon.mid} of '
        '${ninety.tasksInHorizon}',
      ),
    );
    expect(find.text('Over the next 90 days.'), findsOneWidget);
    // The selected option compares with keep going over the same 90 days.
    expect(
      rowText(const Key('selected-workload')),
      contains('Keep going: ${ninety.pressureInHorizon}%'),
    );
    expect(find.textContaining('over the next 90 days'), findsWidgets);
    expect(find.textContaining('over the next 7 days'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('every projected value says Estimate and every recorded count '
      'says From your records', (tester) async {
    await pumpFutureOutcomes(tester);
    void expectLabel(Key key, String label) {
      expect(
        find.descendant(of: find.byKey(key), matching: find.text(label)),
        findsOneWidget,
        reason: '$key',
      );
    }

    expectLabel(const Key('keep-going-workload'), 'Estimate');
    expectLabel(const Key('keep-going-tasks'), 'From your records');
    expectLabel(const Key('keep-going-finish'), 'Estimate');
    expectLabel(const Key('selected-workload'), 'Estimate');
    expectLabel(const Key('selected-pace'), 'Estimate');
    expectLabel(const ValueKey<String>('habit-line-habit-walk'), 'Estimate');
    expectLabel(
      const ValueKey<String>('habit-line-habit-read'),
      'From your records',
    );
    // Goal dates are estimates too.
    final Finder goals = find.byKey(const Key('selected-goal-dates'));
    expect(goals, findsOneWidget);
    expect(
      find.descendant(of: goals, matching: find.text('Estimate')),
      findsWidgets,
    );
    // Nothing on this screen is AI-generated.
    expect(find.text('AI interpretation'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final String language in const <String>['en', 'es']) {
    testWidgets('no prediction is worded as certain ($language)', (
      tester,
    ) async {
      await pumpFutureOutcomes(
        tester,
        locale: Locale(language),
        size: const Size(900, 8000),
      );
      final Set<String> texts = <String>{};
      final TrajectoryComparison comparison = futureOutcomesComparison();
      for (final TrajectoryScenarioOutcome outcome in comparison.outcomes) {
        final Finder card = find.byKey(
          ValueKey<String>('option-${outcome.intervention.id}'),
        );
        if (card.evaluate().isEmpty) continue;
        await tapFutureOutcomes(tester, card);
        await openAllDisclosures(tester);
        texts.addAll(futureOutcomesTexts(tester));
      }
      expect(texts, isNotEmpty);
      final RegExp pattern = language == 'es' ? certainEs : certainEn;
      final List<String> offending = texts
          .where((String t) => pattern.hasMatch(t))
          .toList();
      expect(offending, isEmpty, reason: offending.join('\n'));
      if (language == 'es') {
        // Spanish describes the present, never the future tense.
        final RegExp future = RegExp(r'\p{L}+(rá|rán)(?!\p{L})', unicode: true);
        final List<String> futureTense = texts.where(future.hasMatch).toList();
        expect(futureTense, isEmpty, reason: futureTense.join('\n'));
      }
      // Both languages are checked against both lists of words.
      expect(
        texts.where(certainEn.hasMatch).toList(),
        isEmpty,
        reason: texts.where(certainEn.hasMatch).join('\n'),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('monitoring says forecasts are recorded on this device and '
        'nothing leaves it ($language)', (tester) async {
      final bool es = language == 'es';
      await pumpFutureOutcomes(tester, locale: Locale(language));
      final Finder title = find.text(
        es ? 'Seguimiento de previsiones' : 'Forecast monitoring',
      );
      await tapFutureOutcomes(tester, title);
      expect(
        find.text(
          es
              ? 'La previsión de “seguir como vas” se registra '
                    'automáticamente en este dispositivo: como mucho una vez '
                    'al día para 7 días y una vez a la semana para 30 y 90 '
                    'días. Nada sale de este dispositivo.'
              : 'The “keep going” forecast is recorded automatically on this '
                    'device: at most once a day for 7 days, and once a week '
                    'for 30 and 90 days. Nothing leaves this device.',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the learning state keeps the minimum-evidence wording and '
      'shows no forecast', (tester) async {
    final TrajectoryEngineModel fixture = trajectoryTestEngineModel();
    await pumpFutureOutcomes(
      tester,
      modelFor: (_) => TrajectoryEngineModel(
        status: TrajectoryEngineStatus.learning,
        summary: fixture.summary,
        momentum: fixture.momentum,
        statusDetail:
            'Record 2 more task outcomes before Axiomara compares future '
            'paths. No personal forecast is shown yet.',
        hasAvailableNetworkInterface: true,
      ),
    );
    expect(find.text('Learning your pattern'), findsOneWidget);
    expect(
      find.text(
        'Not enough history yet. Record 2 more task outcomes before Axiomara '
        'compares options. No personal estimate is shown yet.',
      ),
      findsOneWidget,
    );
    expect(find.text('If you keep going as you are'), findsNothing);
    expect(find.text('Options'), findsNothing);
    expect(find.textContaining('Recommended ·'), findsNothing);
    expect(find.text('Recommended adjustment'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final String language in const <String>['en', 'es']) {
    testWidgets('without working hours the recommendation and goal dates are '
        'held back ($language)', (tester) async {
      final bool es = language == 'es';
      final TrajectoryBaseline baseline = futureOutcomesBaseline(
        availabilityOrigin: PredictiveEvidenceOrigin.unavailable,
      );
      final TrajectoryEngineModel fixture = trajectoryTestEngineModel();
      await pumpFutureOutcomes(
        tester,
        locale: Locale(language),
        modelFor: (int days) => TrajectoryEngineModel(
          status: TrajectoryEngineStatus.partial,
          summary: fixture.summary,
          momentum: fixture.momentum,
          comparison: futureOutcomesComparison(baseline: baseline),
          statusDetail:
              'Future paths are conditional models. Working availability is '
              'not configured, so capacity risk, goal dates, and best-fit '
              'claims are withheld.',
          hasAvailableNetworkInterface: true,
        ),
      );
      expect(
        find.text(
          es
              ? 'No has configurado tu horario de trabajo, así que se omiten el '
                    'riesgo de carga, las fechas de las metas y la '
                    'recomendación.'
              : 'Your working hours are not set, so workload risk, goal dates '
                    'and the recommendation are held back.',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining(es ? 'Recomendada ·' : 'Recommended ·'),
        findsNothing,
      );
      expect(
        find.text(es ? 'Ajuste recomendado' : 'Recommended adjustment'),
        findsNothing,
      );
      expect(find.byKey(const Key('selected-goal-dates')), findsNothing);
      expect(
        find.text(
          es
              ? 'Las fechas de las metas y la recomendación se omiten hasta '
                    'que configures tu horario de trabajo.'
              : 'Goal dates and the recommendation are held back until your '
                    'working hours are set.',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('options say the scores are model scores, not chances', (
    tester,
  ) async {
    await pumpFutureOutcomes(tester);
    expect(
      find.text(
        'Pick one to compare it with keeping going. Workload and pace are '
        'model scores, not chances of success; wider ranges are less '
        'reliable.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('risk factors and today figures use the glossary', (
    tester,
  ) async {
    await pumpFutureOutcomes(tester, size: const Size(900, 8000));
    await openAllDisclosures(tester);
    final List<String> texts = futureOutcomesTexts(tester);
    for (final String old in const <String>[
      'Pressure load',
      'Deadline pressure',
      'Capacity overload',
      'Deferral accumulation',
    ]) {
      expect(texts.where((String t) => t.contains(old)), isEmpty, reason: old);
    }
    expect(texts.where((String t) => t.startsWith('• Workload:')), isNotEmpty);
    // Unscheduled work is today's plan, not the selected range.
    final Finder unscheduled = find.ancestor(
      of: find.text('Unscheduled work'),
      matching: find.byType(PlainMetricRow),
    );
    expect(
      find.descendant(
        of: unscheduled,
        matching: find.text('Today, not the selected range.'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('goal dates keep their stated assumption beside them', (
    tester,
  ) async {
    await pumpFutureOutcomes(tester);
    final Finder goals = find.byKey(const Key('selected-goal-dates'));
    expect(goals, findsOneWidget);
    expect(
      find.descendant(
        of: goals,
        matching: find.text(trajectoryGoalDateAssumption),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
