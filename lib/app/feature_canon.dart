import 'package:fantastic_guacamole/app/app_view.dart';
import 'package:fantastic_guacamole/app/router/app_route_registry.dart';
import 'package:fantastic_guacamole/domain/models/chronospark_feature_id.dart';

export 'package:fantastic_guacamole/domain/models/chronospark_feature_id.dart'
    show ChronoSparkFeatureId;

enum ChronoSparkFeatureCategory { primaryCanonFeature, supportSurface }

class ChronoSparkFeatureDefinition {
  const ChronoSparkFeatureDefinition({
    required this.id,
    required this.displayName,
    required this.route,
    required this.purpose,
    required this.category,
  });

  final AppView id;
  final String displayName;
  final String route;
  final String purpose;
  final ChronoSparkFeatureCategory category;
}

/// User-facing product canon derived from the route registry's visible
/// navigation definitions. Hidden routes, including Creator's Goals subroute,
/// remain reachable without becoming advertised standalone surfaces.
abstract final class ChronoSparkFeatureCanon {
  static final List<ChronoSparkFeatureDefinition> active =
      List<ChronoSparkFeatureDefinition>.unmodifiable(
        AppRouteRegistry.visibleNavigationDestinations.map(
          (AppRouteDefinition route) => ChronoSparkFeatureDefinition(
            id: route.appView!,
            displayName: route.label,
            route: route.path,
            purpose: route.navigationSubtitle!,
            category: switch (route.navigationGroup) {
              AppNavigationGroup.primary =>
                ChronoSparkFeatureCategory.primaryCanonFeature,
              AppNavigationGroup.secondary =>
                ChronoSparkFeatureCategory.supportSurface,
              AppNavigationGroup.hidden => throw StateError(
                'Hidden routes cannot enter the active feature canon.',
              ),
            },
          ),
        ),
      );

  static Iterable<ChronoSparkFeatureDefinition> byCategory(
    ChronoSparkFeatureCategory category,
  ) => active.where(
    (ChronoSparkFeatureDefinition feature) => feature.category == category,
  );

  static const Set<String> prohibitedStandaloneProductTerms = <String>{
    'Ses'
        'sion',
    'Fo'
        'cus',
    'In'
        'sight',
    'In'
        'sights',
    'Co'
        'ach',
    'Flowmap',
  };

  static ChronoSparkFeatureDefinition definition(ChronoSparkFeatureId id) {
    final AppView view = switch (id) {
      ChronoSparkFeatureId.nexus => AppView.nexus,
      ChronoSparkFeatureId.smartPlanner => AppView.smartPlanner,
      ChronoSparkFeatureId.creator => AppView.creator,
      ChronoSparkFeatureId.settings => AppView.settings,
      ChronoSparkFeatureId.siConsole => AppView.console,
      ChronoSparkFeatureId.timeline => AppView.timeline,
      ChronoSparkFeatureId.trajectoryEngine => AppView.trajectoryEngine,
      ChronoSparkFeatureId.progression => AppView.progression,
    };
    return active.firstWhere(
      (ChronoSparkFeatureDefinition feature) => feature.id == view,
    );
  }
}
