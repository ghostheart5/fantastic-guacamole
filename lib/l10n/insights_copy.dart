import 'package:fantastic_guacamole/l10n/chronospark_localizations.dart';
import 'package:flutter/widgets.dart';

/// The one source of the names around the Insights tab.
///
/// The tab is "Insights". It has two destinations: "Future outcomes"
/// (estimates, where the tab opens) and "Patterns" (what you recorded). Every
/// place that shows one of these names reads it from here, so a name can only
/// change in one file. The `...En` / `...Es` constants are for code that
/// cannot hold a [BuildContext] (the route registry, const help topics).
class InsightsCopy {
  const InsightsCopy(this.isSpanish);

  factory InsightsCopy.of(BuildContext context) =>
      InsightsCopy(ChronoSparkLocalizations.of(context).isSpanish);

  final bool isSpanish;

  static const String tabNameEn = 'Insights';
  static const String tabNameEs = 'Perspectivas';
  static const String futureOutcomesEn = 'Future outcomes';
  static const String futureOutcomesEs = 'Resultados futuros';
  static const String patternsEn = 'Patterns';
  static const String patternsEs = 'Patrones';

  static const String futureOutcomesSubtitleEn =
      'Explore estimates of what could happen next';
  static const String futureOutcomesSubtitleEs =
      'Explora estimaciones de lo que podría pasar después';
  static const String patternsSubtitleEn =
      'Review your recorded history: tasks, habits and streaks';
  static const String patternsSubtitleEs =
      'Revisa tu historial registrado: tareas, hábitos y rachas';

  static const String todayCardTitleEn = tabNameEn;
  static const String todayCardTitleEs = tabNameEs;
  static const String todayCardSubtitleEn =
      'See your patterns and explore future outcomes.';
  static const String todayCardSubtitleEs =
      'Ve tus patrones y explora resultados futuros.';

  String get tabName => isSpanish ? tabNameEs : tabNameEn;
  String get futureOutcomes => isSpanish ? futureOutcomesEs : futureOutcomesEn;
  String get patterns => isSpanish ? patternsEs : patternsEn;
  String get futureOutcomesSubtitle =>
      isSpanish ? futureOutcomesSubtitleEs : futureOutcomesSubtitleEn;
  String get patternsSubtitle =>
      isSpanish ? patternsSubtitleEs : patternsSubtitleEn;
  String get todayCardTitle => isSpanish ? todayCardTitleEs : todayCardTitleEn;
  String get todayCardSubtitle =>
      isSpanish ? todayCardSubtitleEs : todayCardSubtitleEn;

  /// Accessible name of the two-part switch.
  String get switchLabel =>
      isSpanish ? 'Cambiar de vista en Perspectivas' : 'Switch Insights view';
}
