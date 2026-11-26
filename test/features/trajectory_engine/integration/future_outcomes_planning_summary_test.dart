import 'package:fantastic_guacamole/domain/operating_system/operating_system_contract.dart';
import 'package:fantastic_guacamole/theme/app_theme.dart';
import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:fantastic_guacamole/ui/widgets/decision_intelligence_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/future_outcomes_harness.dart';

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
    expect(find.byType(DecisionIntelligenceCard), findsNothing);
    expect(summary, findsOneWidget);
    final List<String> texts = textsIn(tester, summary);
    expect(texts, contains("Today's planning summary"));
    expect(texts, contains('Workload today'));
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
      texts.where((t) => t.contains('Pace: 52 to 61')),
      isNotEmpty,
      reason: texts.join(' | '),
    );
    expect(
      texts.where((t) => t.contains('Workload: 66 to 58')),
      isNotEmpty,
      reason: texts.join(' | '),
    );
    expect(tester.takeException(), isNull);
  });

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
