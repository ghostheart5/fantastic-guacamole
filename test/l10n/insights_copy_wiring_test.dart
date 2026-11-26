import 'dart:io';

import 'package:fantastic_guacamole/app/app_view.dart';
import 'package:fantastic_guacamole/app/router/app_route_registry.dart';
import 'package:fantastic_guacamole/features/help/help_topics.dart';
import 'package:fantastic_guacamole/l10n/chronospark_localizations.dart';
import 'package:fantastic_guacamole/l10n/insights_copy.dart';
import 'package:fantastic_guacamole/l10n/navigation_copy.dart';
import 'package:fantastic_guacamole/tutorial/guidance_catalogue.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('every place that shows a name reads InsightsCopy', () {
    test('the route registry labels and subtitles', () {
      final AppRouteDefinition patterns = AppRouteRegistry.routeForView(
        AppView.progression,
      );
      final AppRouteDefinition insights = AppRouteRegistry.routeForView(
        AppView.trajectoryEngine,
      );
      expect(patterns.label, InsightsCopy.patternsEn);
      expect(patterns.navigationSubtitle, InsightsCopy.patternsSubtitleEn);
      expect(insights.label, InsightsCopy.tabNameEn);
      expect(
        insights.navigationSubtitle,
        InsightsCopy.futureOutcomesSubtitleEn,
      );
      expect(insights.navigationSubtitle, isNot(contains('predictions')));
    });

    for (final bool spanish in <bool>[false, true]) {
      final String lang = spanish ? 'es' : 'en';
      final InsightsCopy copy = InsightsCopy(spanish);

      test('NavigationCopy ($lang)', () {
        final NavigationCopy navigation = NavigationCopy(spanish);
        final AppRouteDefinition patterns = AppRouteRegistry.routeForView(
          AppView.progression,
        );
        final AppRouteDefinition insights = AppRouteRegistry.routeForView(
          AppView.trajectoryEngine,
        );
        expect(navigation.label(patterns), copy.patterns);
        expect(navigation.subtitle(patterns), copy.patternsSubtitle);
        expect(navigation.label(insights), copy.tabName);
        expect(navigation.subtitle(insights), copy.futureOutcomesSubtitle);
      });

      test('ChronoSparkLocalizations ($lang)', () {
        final ChronoSparkLocalizations strings = ChronoSparkLocalizations(
          Locale(lang),
        );
        expect(strings.text(ChronoSparkString.trajectoryEngine), copy.tabName);
        expect(strings.text(ChronoSparkString.progression), copy.patterns);
        final String overview = strings.text(
          ChronoSparkString.aboutCoreSurfacesBody,
        );
        expect(overview, contains(copy.tabName));
        expect(overview, contains(copy.patterns));
        expect(overview, contains(copy.futureOutcomes));
        expect(overview, isNot(contains(spanish ? 'Actividad' : 'Activity')));
      });

      test('Help topics name the screens ($lang)', () {
        expect(
          HelpTopics.screenName(AppView.trajectoryEngine).of(spanish: spanish),
          copy.tabName,
        );
        expect(
          HelpTopics.screenName(AppView.progression).of(spanish: spanish),
          copy.patterns,
        );
        final String today = HelpTopics.today.body.of(spanish: spanish);
        expect(today, contains(copy.tabName));
        expect(
          today,
          isNot(contains(spanish ? 'ver patrones' : 'see patterns')),
        );
      });

      test('the Patterns guidance hint uses the new name ($lang)', () {
        final GuidanceHint hint = GuidanceCatalogue.progression;
        expect(
          hint.title.of(spanish: spanish),
          contains(copy.patterns.toLowerCase()),
        );
        expect(
          hint.action!.label.of(spanish: spanish).toLowerCase(),
          contains(copy.patterns.toLowerCase()),
        );
      });
    }
  });

  test('the retired names are not shown as a screen name anywhere in lib', () {
    // Exemptions, each with its reason:
    // - account_data_registry.dart: internal owner labels of stored data, never
    //   shown to the person.
    // - the word "activity" as an ordinary word (notifications, "Activity
    //   summary", "Activity type") is not matched by these patterns.
    const Set<String> exempt = <String>{
      'lib/core/data/account_data_registry.dart',
    };
    final List<RegExp> retired = <RegExp>[
      RegExp(r'My patterns & progress', caseSensitive: false),
      RegExp(r'Mis patrones y progreso', caseSensitive: false),
      RegExp(r'Patterns & future outcomes'),
      // Capitalised only: "tus patrones y resultados futuros" in a sentence
      // is ordinary use.
      RegExp(r'Patrones y resultados futuros'),
      // A string that is only the old name.
      RegExp(r'''['"](Activity|Actividad)['"]'''),
      // The old name used as a destination or a feature.
      RegExp(r'\b(Open|Back to|Review \w+ in|in) Activity\b'),
      RegExp(r'\b(en|a) Actividad\b'),
      RegExp(r'Activity (reward|consequences|effects|signals)\b'),
      RegExp(r'ACTIVITY IMPACT'),
      RegExp(r'\bActivity shows\b'),
      RegExp(r'Back to Insights|Volver a Perspectivas'),
    ];
    final List<String> hits = <String>[];
    for (final FileSystemEntity entity in Directory(
      'lib',
    ).listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final String path = entity.path.replaceAll(r'\', '/');
      if (exempt.contains(path)) continue;
      final String text = entity.readAsStringSync();
      for (final RegExp pattern in retired) {
        for (final RegExpMatch match in pattern.allMatches(text)) {
          hits.add('$path: ${match.group(0)}');
        }
      }
    }
    expect(hits, isEmpty);
  });
}
