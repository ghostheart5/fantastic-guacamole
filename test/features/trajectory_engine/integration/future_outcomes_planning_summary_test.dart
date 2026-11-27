import 'package:fantastic_guacamole/domain/operating_system/operating_system_contract.dart';
import 'package:fantastic_guacamole/domain/trajectory/trajectory_consequence_contract.dart';
import 'package:fantastic_guacamole/theme/app_theme.dart';
import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/future_outcomes_harness.dart';
import '../../../helpers/trajectory_test_fixture.dart';

/// Today's planning summary inside "What this is based on": plain rows, the
/// glossary words, captioned as today, readable in both themes, and no
/// wording of certainty (it is shown whenever the decision provider has data).
void main() {
  final Finder summary = find.byKey(
    const Key('future-outcomes-planning-summary'),
  );
  final RegExp certainEn = RegExp(
    r'\b(will|guaranteed?|definitely|certain(ly)?)\b',
    caseSensitive: false,
  );
  final RegExp certainEs = RegExp(
    r'\b(seguro|garantizad\w*|sin duda|con certeza)\b',
    caseSensitive: false,
  );

  Future<void> pumpWithSummary(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
    ThemeData? theme,
    bool firstSummary = false,
    Size size = const Size(900, 8000),
    double textScale = 1,
  }) async {
    final DecisionIntelligence decision = futureOutcomesDecision(
      firstSummary: firstSummary,
    );
    await pumpFutureOutcomes(
      tester,
      locale: locale,
      theme: theme,
      size: size,
      textScale: textScale,
      modelFor: (int days) =>
          futureOutcomesModel(days: days, decision: decision),
    );
    await openAllDisclosures(tester);
  }

  List<String> textsIn(WidgetTester tester, Finder of) => tester
      .widgetList<Text>(find.descendant(of: of, matching: find.byType(Text)))
      .map((Text t) => t.data ?? t.textSpan?.toPlainText() ?? '')
      .where((String s) => s.isNotEmpty)
      .toList();

  testWidgets('shown as plain rows, not the old dark card', (tester) async {
    await pumpWithSummary(tester);
    expect(summary, findsOneWidget);
    final List<String> texts = textsIn(tester, summary);
    expect(texts, contains("Today's planning summary"));
    // The old task-count score is not shown here: the forecast's workload is
    // the only figure called workload on this screen.
    expect(texts, isNot(contains('Workload today')));
    expect(texts, contains('Pace today'));
    expect(texts, contains('Draft the proposal'));
    expect(
      texts.where((t) => t.contains('Today, not the selected range')),
      isNotEmpty,
    );
    // Glossary words, no capitals-only labels, no old score words.
    for (final String text in texts) {
      final String letters = text.replaceAll(RegExp(r'[^A-Za-zÁÉÍÓÚÑ]'), '');
      expect(
        letters.length > 3 && letters == letters.toUpperCase(),
        isFalse,
        reason: text,
      );
      expect(text, isNot(contains('Momentum')), reason: text);
      // The old "Momentum N%, pressure N%" figures are gone (a producer
      // sentence may still say "overdue pressure" in plain words).
      expect(text, isNot(contains(RegExp(r'[Pp]ressure:? \d'))), reason: text);
    }
    // The change list uses the glossary too.
    expect(
      texts.where((t) => t.contains('Pace: 52 to 61 of 100')),
      isNotEmpty,
      reason: texts.join(' | '),
    );
    expect(
      texts.where((t) => t.contains('Workload:')),
      isEmpty,
      reason: texts.join(' | '),
    );
    expect(tester.takeException(), isNull);
  });

  // Change lines carry units, as the figures do in their own rows.
  for (final String language in const <String>['en', 'es']) {
    testWidgets('change lines give units ($language)', (tester) async {
      final DecisionIntelligence base = futureOutcomesDecision();
      OperatingSnapshot covering(double coverage, int momentum) =>
          OperatingSnapshot(
            accountScope: base.snapshot.accountScope,
            observedAt: base.snapshot.observedAt,
            sourceRevisions: base.snapshot.sourceRevisions,
            activeGoalCount: base.snapshot.activeGoalCount,
            actionableCount: base.snapshot.actionableCount,
            overdueCount: base.snapshot.overdueCount,
            completedToday: base.snapshot.completedToday,
            energy: base.snapshot.energy,
            fatigue: base.snapshot.fatigue,
            momentum: momentum,
            pressure: base.snapshot.pressure,
            topActionId: base.snapshot.topActionId,
            topActionLabel: base.snapshot.topActionLabel,
            activeRisks: base.snapshot.activeRisks,
            evidenceCoverage: coverage,
          );
      final OperatingSnapshot current = covering(.9, 61);
      final DecisionIntelligence decision = DecisionIntelligence(
        snapshot: current,
        delta: const OperatingDeltaEngine().compare(
          previous: covering(.6, 52),
          current: current,
          comparedAt: trajectoryFixtureNow,
        ),
        decision: base.decision,
        acknowledgedSnapshotId: null,
      );
      await pumpFutureOutcomes(
        tester,
        locale: Locale(language),
        size: const Size(900, 8000),
        modelFor: (int days) =>
            futureOutcomesModel(days: days, decision: decision),
      );
      await openAllDisclosures(tester);
      final String changes = textsIn(tester, summary).join(' | ');
      if (language == 'es') {
        expect(changes, contains('Ritmo: 52 a 61 de 100'));
        expect(changes, contains('Registros disponibles: 60% a 90%'));
      } else {
        expect(changes, contains('Pace: 52 to 61 of 100'));
        expect(changes, contains('Records available: 60% to 90%'));
      }
      expect(tester.takeException(), isNull);
    });
  }

  // The audit's case: seven small undated tasks, three recorded outcomes and
  // an 8-hour day. The forecast's workload is light; the old task-count score
  // (7 × 16, clamped to 100) must not appear as a second "workload" anywhere.
  for (final String language in const <String>['en', 'es']) {
    testWidgets('only one thing called workload: the forecast\'s ($language)', (
      tester,
    ) async {
      final List<TrajectoryTaskNode> tasks = <TrajectoryTaskNode>[
        for (int i = 0; i < 7; i++)
          TrajectoryTaskNode(
            id: 'small-$i',
            title: 'Small task $i',
            priority: 2,
            estimatedMinutes: 15,
          ),
      ];
      final TrajectoryBaseline baseline = trajectoryTestBaseline(
        tasks: tasks,
        dailyFreeMinutes: 480,
        observationCount: 3,
        completedInWindow: 3,
      );
      final DecisionIntelligence base = futureOutcomesDecision();
      OperatingSnapshot heavy(OperatingSnapshot s, int pressure) =>
          OperatingSnapshot(
            accountScope: s.accountScope,
            observedAt: s.observedAt,
            sourceRevisions: s.sourceRevisions,
            activeGoalCount: s.activeGoalCount,
            actionableCount: 7,
            overdueCount: s.overdueCount,
            completedToday: s.completedToday,
            energy: s.energy,
            fatigue: s.fatigue,
            momentum: s.momentum,
            pressure: pressure,
            topActionId: s.topActionId,
            topActionLabel: s.topActionLabel,
            activeRisks: s.activeRisks,
            evidenceCoverage: s.evidenceCoverage,
          );
      final OperatingSnapshot current = heavy(base.snapshot, 100);
      final OperatingSnapshot previous = heavy(base.snapshot, 66);
      final DecisionIntelligence decision = DecisionIntelligence(
        snapshot: current,
        delta: const OperatingDeltaEngine().compare(
          previous: previous,
          current: current,
          comparedAt: trajectoryFixtureNow,
        ),
        decision: base.decision,
        acknowledgedSnapshotId: null,
      );
      expect(baseline.pressureInHorizon, lessThan(20));
      await pumpFutureOutcomes(
        tester,
        locale: Locale(language),
        size: const Size(900, 8000),
        modelFor: (int days) => futureOutcomesModel(
          days: days,
          decision: decision,
          comparison: trajectoryTestComparison(baseline: baseline),
        ),
      );
      await openAllDisclosures(tester);
      final List<String> texts = futureOutcomesTexts(tester);
      expect(texts, isNotEmpty);
      final RegExp oldRow = RegExp(
        r'Workload today|Carga de trabajo hoy|Workload: \d+%? to |'
        r'Carga de trabajo: \d+%? a ',
      );
      final RegExp oldFigure = RegExp(r'\b100%');
      final List<String> bad = texts
          .where((String t) => oldRow.hasMatch(t) || oldFigure.hasMatch(t))
          .toList();
      expect(bad, isEmpty, reason: bad.join('\n'));
      expect(tester.takeException(), isNull);
    });
  }

  for (final String language in const <String>['en', 'es']) {
    for (final bool first in const <bool>[true, false]) {
      testWidgets('no certainty words ($language, first summary: $first)', (
        tester,
      ) async {
        await pumpWithSummary(
          tester,
          locale: Locale(language),
          firstSummary: first,
        );
        final List<String> texts = textsIn(tester, summary);
        expect(texts, isNotEmpty);
        final RegExp pattern = language == 'es' ? certainEs : certainEn;
        final List<String> bad = texts
            .where((t) => pattern.hasMatch(t) || certainEn.hasMatch(t))
            .toList();
        expect(bad, isEmpty, reason: bad.join('\n'));
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final ThemeData theme in <ThemeData>[appTheme, appLightTheme]) {
    testWidgets('every summary text is readable (${theme.brightness.name})', (
      tester,
    ) async {
      await pumpWithSummary(tester, theme: theme);
      expect(summary, findsOneWidget);
      final Color card = Color.alphaBlend(
        theme.cardTheme.color ?? theme.colorScheme.surface,
        AppColors.background,
      );
      double luminance(Color c) => c.computeLuminance();
      final List<String> low = <String>[];
      for (final Element element
          in find
              .descendant(of: summary, matching: find.byType(RichText))
              .evaluate()) {
        final RenderParagraph paragraph =
            element.renderObject! as RenderParagraph;
        final Color? color = paragraph.text.style?.color;
        if (color == null) continue;
        final Color shown = Color.alphaBlend(color, card);
        final double a = luminance(shown);
        final double b = luminance(card);
        final double ratio = a > b
            ? (a + .05) / (b + .05)
            : (b + .05) / (a + .05);
        if (ratio < 4.5) {
          low.add('${paragraph.text.toPlainText()} ($ratio)');
        }
      }
      expect(low, isEmpty, reason: low.join('\n'));
    });
  }

  for (final ThemeData theme in <ThemeData>[appTheme, appLightTheme]) {
    for (final String language in const <String>['en', 'es']) {
      testWidgets('fits 320 dp at text scale 2.0 ($language, '
          '${theme.brightness.name})', (tester) async {
        await pumpWithSummary(
          tester,
          locale: Locale(language),
          theme: theme,
          size: const Size(320, 30000),
          textScale: 2,
        );
        expect(summary, findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
