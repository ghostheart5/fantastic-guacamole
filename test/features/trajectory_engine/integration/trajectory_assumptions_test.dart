import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/repositories/trajectory_forecast_ledger_repository.dart';
import 'package:fantastic_guacamole/domain/predictive/predictive_planning_contract.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_consequence_provider.dart';
import 'package:fantastic_guacamole/domain/trajectory/trajectory_consequence_contract.dart';
import 'package:fantastic_guacamole/ui/widgets/plain/plain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/trajectory_screen_harness.dart';
import '../../../helpers/trajectory_test_fixture.dart';

/// The selected option's assumptions on Future outcomes: optional, complete,
/// plainly worded, and shared information is shown once with its framing.
/// (Split out of the former trajectory_engine_integration_test.dart.)
void main() {
  Finder bulletsIn(Finder section) => find.descendant(
    of: section,
    matching: find.byWidgetPredicate(
      (widget) => widget is Text && (widget.data?.startsWith('• ') ?? false),
    ),
  );

  for (final language in ['en', 'es']) {
    final String title = language == 'es'
        ? 'Supuestos de esta estimación'
        : 'What this estimate assumes';

    testWidgets('forecast assumptions are optional and complete in $language', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(900, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final store = TrajectoryMemoryStore();
      final scope = AccountStorageScope.authenticated('test-account');
      final comparison = trajectoryModelForScope(
        scope.v2Namespace!,
      ).comparison!;
      final outcome = comparison.outcomes.firstWhere(
        (value) => value.intervention.id == 'planner',
      );
      final section = find.byKey(
        ValueKey<String>('trajectory-assumptions-${outcome.id}'),
      );
      final notice = language == 'es'
          ? 'Explorar esta estimación no cambia tu plan guardado.'
          : 'Exploring this estimate does not change your saved plan.';
      await tester.pumpWidget(
        trajectoryScreenHarness(
          model: trajectoryModelWithOutcomes(comparison, [outcome]),
          locale: Locale(language),
          repository: TrajectoryForecastLedgerRepository(
            store: store,
            scope: scope,
          ),
        ),
      );
      await pumpTrajectoryTransition(tester);
      await tester.ensureVisible(find.text(notice));
      await pumpTrajectoryTransition(tester);
      expect(find.text(notice).hitTestable(), findsOneWidget);
      expect(bulletsIn(section), findsNothing);
      await tapTrajectory(tester, find.text(title));
      expect(
        bulletsIn(section),
        findsNWidgets(
          outcome.assumptions.where((value) => value.trim().isNotEmpty).length,
        ),
      );
      await tapTrajectory(tester, find.text(title));
      expect(bulletsIn(section), findsNothing);
      expect(store.writes, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('range and free-time assumptions read plainly in $language', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(900, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final scope = AccountStorageScope.authenticated('test-account');
      final comparison = trajectoryTestComparison(
        baseline: trajectoryTestBaseline(
          accountScope: scope.v2Namespace!,
          assumptions: const <String>[
            trajectoryAssumedWorkdayAssumption,
            trajectoryUndatedTasksAssumption,
          ],
        ),
      );
      final outcome = comparison.outcomes.firstWhere(
        (value) => value.intervention.id == 'planner',
      );
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
      await tapTrajectory(tester, find.text(title));
      final Finder section = find.byKey(
        ValueKey<String>('trajectory-assumptions-${outcome.id}'),
      );
      final List<String> expected = language == 'es'
          ? const <String>[
              'El tiempo libre se basa en una jornada supuesta porque no hay horario de trabajo configurado.',
              'Las tareas sin fecha cuentan en todos los periodos.',
              'Las fechas de las metas suponen que tu tiempo libre diario se dedica a las tareas pendientes de la meta; otro trabajo puede retrasarlas.',
            ]
          : const <String>[
              trajectoryAssumedWorkdayAssumption,
              trajectoryUndatedTasksAssumption,
              trajectoryGoalDateAssumption,
            ];
      for (final String text in expected) {
        expect(
          find.descendant(of: section, matching: find.textContaining(text)),
          findsOneWidget,
        );
      }
      expect(tester.takeException(), isNull);
    });
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
      trajectoryScreenHarness(
        model: trajectoryModelWithOutcomes(comparison, [
          comparison.outcomes[1],
        ]),
      ),
    );
    await pumpTrajectoryTransition(tester);
    expect(find.text('Some information is missing'), findsOneWidget);
    final Finder section = find.byKey(
      ValueKey<String>('trajectory-assumptions-${comparison.outcomes[1].id}'),
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
    await tapTrajectory(tester, find.text('What this estimate assumes'));
    expect(
      find.descendant(
        of: section,
        matching: find.textContaining(
          'Information you shared: Explicit boundary excludes task-polish.',
        ),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Person Context constraint:'), findsNothing);
    expect(
      find.textContaining(
        'Capacity-based risk and goal completion dates are withheld.',
      ),
      findsOneWidget,
    );
    // The evidence origin is stated in "What this is based on".
    await tapTrajectory(tester, find.text('What this is based on'));
    expect(
      find.textContaining('Energy: estimated; not recorded.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  for (final language in ['en', 'es']) {
    testWidgets(
      'paired shared-information warnings preserve qualifiers once in $language',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(900, 1800));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        const explanation = 'Explicit boundary excludes task-polish.';
        const paired =
            'User-reported Person Context: $explanation It constrains this scenario but is not treated as identity or a guaranteed outcome.';
        const unrelatedNote = 'A different user-authored note.';
        const unrelated =
            'User-reported Person Context: $unrelatedNote It constrains this scenario but is not treated as identity or a guaranteed outcome.';
        const unrelatedConstraint =
            'Person Context constraint: User-authored note, not a baseline warning.';
        final scope = AccountStorageScope.authenticated('test-account');
        final comparison = trajectoryTestComparison(
          baseline: trajectoryTestBaseline(
            accountScope: scope.v2Namespace!,
            personContextWarnings: [explanation],
          ),
          plannerAssumptions: [paired, unrelated, unrelatedConstraint],
        );
        final outcome = comparison.outcomes.firstWhere(
          (value) => value.intervention.id == 'planner',
        );
        // Exercise the real engine pair, not a hand-deduplicated UI fixture.
        expect(outcome.assumptions, contains(paired));
        expect(
          outcome.assumptions,
          contains('Person Context constraint: $explanation'),
        );
        final section = find.byKey(
          ValueKey<String>('trajectory-assumptions-${outcome.id}'),
        );
        final title = language == 'es'
            ? 'Supuestos de esta estimación'
            : 'What this estimate assumes';
        String framed(String note) => language == 'es'
            ? 'Información que compartiste: $note Limita esta estimación, pero no te define ni promete un resultado.'
            : 'Information you shared: $note It limits this estimate but does not define you or promise an outcome.';
        final store = TrajectoryMemoryStore();
        await tester.pumpWidget(
          trajectoryScreenHarness(
            model: trajectoryModelWithOutcomes(comparison, [outcome]),
            locale: Locale(language),
            repository: TrajectoryForecastLedgerRepository(
              store: store,
              scope: scope,
            ),
          ),
        );
        await pumpTrajectoryTransition(tester);
        expect(find.textContaining(explanation), findsNothing);
        await tapTrajectory(tester, find.text(title));
        Finder withinAssumptions(Finder matching) =>
            find.descendant(of: section, matching: matching);
        expect(
          withinAssumptions(find.textContaining(explanation)),
          findsOneWidget,
        );
        expect(
          withinAssumptions(find.text('• ${framed(explanation)}')),
          findsOneWidget,
        );
        expect(withinAssumptions(find.text('• $paired')), findsNothing);
        expect(
          withinAssumptions(
            find.text('• Person Context constraint: $explanation'),
          ),
          findsNothing,
        );
        // An unpaired note keeps its own words; only the framing changes, so
        // no "guaranteed" wording reaches the screen.
        expect(
          withinAssumptions(find.text('• ${framed(unrelatedNote)}')),
          findsOneWidget,
        );
        expect(withinAssumptions(find.text('• $unrelated')), findsNothing);
        expect(
          withinAssumptions(find.text('• $unrelatedConstraint')),
          findsOneWidget,
        );
        expect(store.writes, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final language in ['en', 'es']) {
    for (final paired in [true, false]) {
      testWidgets(
        'structured warnings preserve quoted titles in $language paired=$paired',
        (tester) async {
          await tester.binding.setSurfaceSize(const Size(900, 1800));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          const labels = '"Revisar José’s résumé", "Llamar a Zoë"';
          const warnings = <String>[
            'Current priority matched $labels and may only break a close ranking tie.',
            'Explicit boundary excluded $labels from this decision.',
            'Fresh capacity limited this decision to 35 minutes.',
            'Scheduled commitment protected $labels during conflict checks.',
          ];
          const spanishWarnings = <String>[
            'La prioridad actual coincide con $labels y solo puede desempatar opciones de valoración similar.',
            'El límite explícito excluyó $labels de esta decisión.',
            'Tu capacidad actual limita hoy a 35 minutos. Los demás días del periodo usan tu tiempo libre habitual.',
            'El compromiso programado protegió $labels al comprobar conflictos.',
          ];
          // The capacity limit is worded as the forecast applies it: today
          // only.
          final englishWarnings = <String>[
            for (final warning in warnings)
              warning.startsWith('Fresh capacity')
                  ? 'Your capacity right now limits today to 35 minutes. Later days in the range use your usual free time.'
                  : warning,
          ];
          const unknown =
              'Explicit boundary excluded "Texto mío" from this decision.';
          const unknownNote = 'A user note outside the structured warnings.';
          const unknownReported =
              'User-reported Person Context: $unknownNote It constrains this scenario but is not treated as identity or a guaranteed outcome.';
          final reported = <String>[
            for (final warning in warnings)
              'User-reported Person Context: $warning It constrains this scenario but is not treated as identity or a guaranteed outcome.',
          ];
          final scope = AccountStorageScope.authenticated('test-account');
          final store = TrajectoryMemoryStore();
          final comparison = trajectoryTestComparison(
            baseline: trajectoryTestBaseline(
              accountScope: scope.v2Namespace!,
              personContextWarnings: warnings,
            ),
            plannerAssumptions: [
              if (paired) ...reported,
              unknown,
              unknownReported,
            ],
          );
          final outcome = comparison.outcomes.firstWhere(
            (value) => value.intervention.id == 'planner',
          );
          for (final warning in warnings) {
            expect(
              outcome.assumptions,
              contains('Person Context constraint: $warning'),
            );
          }
          await tester.pumpWidget(
            trajectoryScreenHarness(
              model: trajectoryModelWithOutcomes(comparison, [outcome]),
              locale: Locale(language),
              repository: TrajectoryForecastLedgerRepository(
                store: store,
                scope: scope,
              ),
            ),
          );
          await pumpTrajectoryTransition(tester);
          final title = language == 'es'
              ? 'Supuestos de esta estimación'
              : 'What this estimate assumes';
          final section = find.byKey(
            ValueKey<String>('trajectory-assumptions-${outcome.id}'),
          );
          await tapTrajectory(tester, find.text(title));
          final rendered = tester
              .widgetList<Text>(
                find.descendant(of: section, matching: find.byType(Text)),
              )
              .map((text) => text.data ?? '')
              .join('\n');
          final prefix = language == 'es'
              ? 'Información que compartiste: '
              : 'Information you shared: ';
          final qualifier = language == 'es'
              ? ' Limita esta estimación, pero no te define ni promete un resultado.'
              : ' It limits this estimate but does not define you or promise an outcome.';
          for (var index = 0; index < warnings.length; index++) {
            final expectedWarning = language == 'es'
                ? spanishWarnings[index]
                : englishWarnings[index];
            final expected =
                '$prefix$expectedWarning${paired ? qualifier : ''}';
            expect(
              RegExp(RegExp.escape(expected)).allMatches(rendered),
              hasLength(1),
            );
            expect(
              rendered,
              isNot(contains('Person Context constraint: ${warnings[index]}')),
            );
            expect(rendered, isNot(contains(reported[index])));
          }
          // The four paired warnings, plus the unpaired note's own framing.
          expect(
            RegExp(RegExp.escape(qualifier)).allMatches(rendered),
            hasLength(paired ? 5 : 1),
          );
          expect(rendered, contains(labels));
          expect(rendered, contains(unknown));
          expect(rendered, contains('$prefix$unknownNote$qualifier'));
          expect(rendered, isNot(contains('guaranteed')));
          expect(store.writes, 0);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final language in ['en', 'es']) {
    testWidgets('baseline evidence localizes structured warnings in $language', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(900, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      const labels = '"Revisar José’s résumé", "Llamar a Zoë"';
      const warnings = <String>[
        'Current priority matched $labels and may only break a close ranking tie.',
        'Explicit boundary excluded $labels from this decision.',
        'Fresh capacity limited this decision to 35 minutes.',
        'Scheduled commitment protected $labels during conflict checks.',
      ];
      const spanishWarnings = <String>[
        'La prioridad actual coincide con $labels y solo puede desempatar opciones de valoración similar.',
        'El límite explícito excluyó $labels de esta decisión.',
        'Tu capacidad actual limita hoy a 35 minutos. Los demás días del periodo usan tu tiempo libre habitual.',
        'El compromiso programado protegió $labels al comprobar conflictos.',
      ];
      final englishWarnings = <String>[
        for (final warning in warnings)
          warning.startsWith('Fresh capacity')
              ? 'Your capacity right now limits today to 35 minutes. Later days in the range use your usual free time.'
              : warning,
      ];
      const unknown =
          'User note: $labels remains outside known warning templates.';
      final scope = AccountStorageScope.authenticated('test-account');
      final store = TrajectoryMemoryStore();
      final baseline = trajectoryTestBaseline(
        accountScope: scope.v2Namespace!,
        personContextWarnings: [...warnings, unknown],
      );
      final comparison = trajectoryTestComparison(baseline: baseline);
      await tester.pumpWidget(
        trajectoryScreenHarness(
          model: trajectoryModelWithOutcomes(comparison, [
            comparison.outcomes.first,
          ]),
          locale: Locale(language),
          repository: TrajectoryForecastLedgerRepository(
            store: store,
            scope: scope,
          ),
        ),
      );
      await pumpTrajectoryTransition(tester);
      await tapTrajectory(
        tester,
        find.text(
          language == 'es' ? 'En qué se basa' : 'What this is based on',
        ),
      );
      final Finder details = find.byKey(
        const Key('future-outcomes-based-on-details'),
      );
      expect(
        find.descendant(
          of: details,
          matching: find.text(
            language == 'es'
                ? 'Información que compartiste'
                : 'Information you shared',
          ),
        ),
        findsOneWidget,
      );
      for (var index = 0; index < warnings.length; index++) {
        expect(
          find.text(
            '• ${language == 'es' ? spanishWarnings[index] : englishWarnings[index]}',
          ),
          findsOneWidget,
        );
        if (language == 'es') {
          expect(find.text('• ${warnings[index]}'), findsNothing);
        }
      }
      expect(find.text('• $unknown'), findsOneWidget);
      final summary = language == 'es'
          ? 'Esta estimación: ${baseline.availableMinutes} min disponibles / ${baseline.unscheduledMinutes} min sin programar. Comparación sin información compartida: ${baseline.noContextAvailableMinutes} min disponibles / ${baseline.noContextUnscheduledMinutes} min sin programar.'
          : 'This estimate: ${baseline.availableMinutes}m available / ${baseline.unscheduledMinutes}m unscheduled. Comparison without shared information: ${baseline.noContextAvailableMinutes}m available / ${baseline.noContextUnscheduledMinutes}m unscheduled.';
      expect(find.text(summary), findsOneWidget);
      expect(
        find.textContaining('Contexto personal autorizado:'),
        findsNothing,
      );
      expect(store.writes, 0);
      expect(tester.takeException(), isNull);
    });
  }

  for (final language in ['en', 'es']) {
    testWidgets('unavailable shared-information fallbacks render in $language', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(900, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      const raw = <String>[
        'Person context was unavailable at scenario construction, so no personal context was inferred.',
        'The no-context capacity and unscheduled values remain available for comparison.',
      ];
      final expected = language == 'es'
          ? <String>[
              'La información personal compartida no estaba disponible, por lo que no se dedujo para esta estimación.',
              'Las estimaciones de capacidad y trabajo sin programar calculadas sin información personal compartida siguen disponibles para comparar.',
            ]
          : <String>[
              'Shared personal information was unavailable, so none was inferred for this estimate.',
              'Capacity and unscheduled-work estimates without shared personal information remain available for comparison.',
            ];
      final scope = AccountStorageScope.authenticated('test-account');
      final store = TrajectoryMemoryStore();
      final comparison = trajectoryTestComparison(
        baseline: trajectoryTestBaseline(
          accountScope: scope.v2Namespace!,
          availabilityOrigin: PredictiveEvidenceOrigin.unavailable,
        ),
        plannerAssumptions: raw,
      );
      final outcome = comparison.outcomes.firstWhere(
        (value) => value.intervention.id == 'planner',
      );
      await tester.pumpWidget(
        trajectoryScreenHarness(
          model: trajectoryModelWithOutcomes(comparison, [outcome]),
          locale: Locale(language),
          repository: TrajectoryForecastLedgerRepository(
            store: store,
            scope: scope,
          ),
        ),
      );
      await pumpTrajectoryTransition(tester);
      await tapTrajectory(
        tester,
        find.text(
          language == 'es'
              ? 'Supuestos de esta estimación'
              : 'What this estimate assumes',
        ),
      );
      for (final value in expected) {
        expect(find.text('• $value'), findsOneWidget);
      }
      for (final value in raw) {
        expect(find.text('• $value'), findsNothing);
      }
      expect(store.writes, 0);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('forecast assumptions reset when the selected outcome changes', (
    tester,
  ) async {
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
      trajectoryScreenHarness(
        model: trajectoryModelWithOutcomes(comparison, [first]),
      ),
    );
    await pumpTrajectoryTransition(tester);
    await tapTrajectory(tester, find.text('What this estimate assumes'));
    expect(
      find.textContaining('The protected block is attempted.'),
      findsOneWidget,
    );
    await tester.pumpWidget(
      trajectoryScreenHarness(
        model: trajectoryModelWithOutcomes(comparison, [second]),
      ),
    );
    await pumpTrajectoryTransition(tester);
    expect(
      find.textContaining('The protected block is attempted.'),
      findsNothing,
    );
    final section = find.byKey(
      ValueKey<String>('trajectory-assumptions-${second.id}'),
    );
    final disclosure = tester.widget<PlainDisclosure>(
      find.descendant(of: section, matching: find.byType(PlainDisclosure)),
    );
    expect(disclosure.initiallyExpanded, isFalse);
    expect(bulletsIn(section), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('forecast assumptions fit narrow Spanish enlarged text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      trajectoryScreenHarness(locale: const Locale('es'), textScale: 2),
    );
    await pumpTrajectoryTransition(tester);
    final title = find.text('Supuestos de esta estimación');
    await tester.scrollUntilVisible(
      title.hitTestable(),
      180,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 160,
    );
    await tester.ensureVisible(title);
    await pumpTrajectoryTransition(tester);
    final bounds = tester.getRect(title);
    expect(bounds.left, greaterThanOrEqualTo(0));
    expect(bounds.right, lessThanOrEqualTo(320));
    expect(title.hitTestable(), findsOneWidget);
    await tester.tap(title.hitTestable());
    await pumpTrajectoryTransition(tester);
    expect(find.textContaining('Esta estimación cambia solo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
