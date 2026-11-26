import 'package:fantastic_guacamole/l10n/insights_copy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the owner-decided names in English and Spanish', () {
    const InsightsCopy en = InsightsCopy(false);
    const InsightsCopy es = InsightsCopy(true);
    expect(en.tabName, 'Insights');
    expect(es.tabName, 'Perspectivas');
    expect(en.futureOutcomes, 'Future outcomes');
    expect(es.futureOutcomes, 'Resultados futuros');
    expect(en.patterns, 'Patterns');
    expect(es.patterns, 'Patrones');
    expect(en.todayCardTitle, 'Insights');
    expect(es.todayCardTitle, 'Perspectivas');
  });

  test('every string is filled, differs between languages and is plain', () {
    const InsightsCopy en = InsightsCopy(false);
    const InsightsCopy es = InsightsCopy(true);
    final List<(String, String)> pairs = <(String, String)>[
      (en.futureOutcomesSubtitle, es.futureOutcomesSubtitle),
      (en.patternsSubtitle, es.patternsSubtitle),
      (en.todayCardSubtitle, es.todayCardSubtitle),
      (en.switchLabel, es.switchLabel),
    ];
    for (final (String english, String spanish) in pairs) {
      expect(english.trim(), isNotEmpty);
      expect(spanish.trim(), isNotEmpty);
      expect(english, isNot(spanish));
    }
    // Estimates are never worded as certain.
    final RegExp certain = RegExp(
      r'\b(will|guaranteed?|definitely|certain(ly)?|seguro|garantizad\w*)\b',
      caseSensitive: false,
    );
    for (final (String english, String spanish) in pairs) {
      expect(certain.hasMatch(english), isFalse, reason: english);
      expect(certain.hasMatch(spanish), isFalse, reason: spanish);
    }
  });
}
