import 'dart:ui' as ui;

import 'package:fantastic_guacamole/theme/app_theme.dart';
import 'package:fantastic_guacamole/ui/navigation/insights_destination_switch.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/future_outcomes_harness.dart';

/// Future outcomes at large text on a narrow phone, tap targets, and what
/// screen readers hear for the range, the switch and the option cards.
void main() {
  for (final ThemeData theme in <ThemeData>[appTheme, appLightTheme]) {
    for (final String language in const <String>['en', 'es']) {
      testWidgets('no overflow at text scale 2.0 on 320 dp ($language, '
          '${theme.brightness.name} theme)', (tester) async {
        await pumpFutureOutcomes(
          tester,
          locale: Locale(language),
          theme: theme,
          size: const Size(320, 24000),
          textScale: 2,
        );
        expect(tester.takeException(), isNull);
        await openAllDisclosures(tester);
        expect(tester.takeException(), isNull);
        // Every text stays inside the 320 dp page.
        final List<String> outside = <String>[];
        for (final Element element in find.byType(Text).evaluate()) {
          final RenderObject? object = element.renderObject;
          if (object is! RenderBox || !object.hasSize || !object.attached) {
            continue;
          }
          // Painted bounds (a floating field label is drawn scaled down).
          final Rect rect = MatrixUtils.transformRect(
            object.getTransformTo(null),
            Offset.zero & object.size,
          );
          if (rect.left < -0.5 || rect.right > 320.5) {
            outside.add('${(element.widget as Text).data} $rect');
          }
        }
        expect(outside, isEmpty, reason: outside.join(r' / '));
      });
    }
  }

  testWidgets('every control is at least 48 by 48', (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await pumpFutureOutcomes(tester, size: const Size(400, 6000));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await openAllDisclosures(tester);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    handle.dispose();
  });

  for (final String language in const <String>['en', 'es']) {
    testWidgets('the range and the switch announce their selected state '
        '($language)', (tester) async {
      final bool es = language == 'es';
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpFutureOutcomes(tester, locale: Locale(language));
      SemanticsData chip(String label) => tester
          .getSemantics(
            find.ancestor(
              of: find.text(label),
              matching: find.byType(ChoiceChip),
            ),
          )
          .getSemanticsData();
      expect(
        chip(es ? '7 días' : '7 days').flagsCollection.isSelected,
        ui.Tristate.isTrue,
      );
      expect(
        chip(es ? '30 días' : '30 days').flagsCollection.isSelected,
        ui.Tristate.isFalse,
      );
      expect(find.byKey(InsightsDestinationSwitch.switchKey), findsOneWidget);
      SemanticsData segment(String label) => tester
          .getSemantics(find.bySemanticsLabel(label).last)
          .getSemanticsData();
      expect(
        segment(
          es ? 'Resultados futuros' : 'Future outcomes',
        ).flagsCollection.isSelected,
        ui.Tristate.isTrue,
      );
      expect(
        segment(es ? 'Patrones' : 'Patterns').flagsCollection.isSelected,
        ui.Tristate.isFalse,
      );
      await tapFutureOutcomes(tester, find.text(es ? '30 días' : '30 days'));
      expect(
        chip(es ? '30 días' : '30 days').flagsCollection.isSelected,
        ui.Tristate.isTrue,
      );
      handle.dispose();
    });
  }

  testWidgets('option cards are announced as selected or not selected', (
    tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await pumpFutureOutcomes(tester);
    SemanticsData card(String id) => tester
        .getSemantics(find.byKey(ValueKey<String>('option-$id')))
        .getSemanticsData();
    final List<String> ids = <String>[
      'complete-task-a',
      'planner',
      'remove-task-d',
    ];
    for (final String id in ids) {
      expect(card(id).flagsCollection.isButton, isTrue, reason: id);
      expect(card(id).flagsCollection.isSelected, isNot(ui.Tristate.none));
    }
    // The recommended option starts selected.
    expect(
      card('complete-task-a').flagsCollection.isSelected,
      ui.Tristate.isTrue,
    );
    expect(card('planner').flagsCollection.isSelected, ui.Tristate.isFalse);
    await tapFutureOutcomes(
      tester,
      find.byKey(const ValueKey<String>('option-planner')),
    );
    expect(card('planner').flagsCollection.isSelected, ui.Tristate.isTrue);
    expect(
      card('complete-task-a').flagsCollection.isSelected,
      ui.Tristate.isFalse,
    );
    // The card is announced from its own words.
    expect(card('planner').label, contains('Keep the suggested plan'));
    handle.dispose();
  });
}
