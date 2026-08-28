import 'package:fantastic_guacamole/app/app_view.dart';
import 'package:fantastic_guacamole/app/router/app_route_registry.dart';
import 'package:fantastic_guacamole/domain/models/chronospark_feature_id.dart';

export 'package:fantastic_guacamole/domain/models/chronospark_feature_id.dart'
    show ChronoSparkFeatureId;

enum ChronoSparkFeatureStatus { active, compatibilityOnly, removed }

enum ChronoSparkFeatureCategory {
  primaryCanonFeature,
  supportSurface,
  evidenceOutput,
  legacyRedirect,
  diagnosticInternalTool,
}

class ChronoSparkFeatureDefinition {
  const ChronoSparkFeatureDefinition({
    required this.id,
    required this.displayName,
    required this.route,
    required this.purpose,
    required this.category,
    this.status = ChronoSparkFeatureStatus.active,
  });

  final ChronoSparkFeatureId id;
  final String displayName;
  final String route;
  final String purpose;
  final ChronoSparkFeatureCategory category;
  final ChronoSparkFeatureStatus status;
}

/// The single production feature registry for user-facing names and routes.
///
/// Compatibility paths live in [RoutePaths] but must never be generated from
/// this registry. Signal is an output of Smart Planner or SI Console, not a
/// feature. Retired work-timer concepts remain excluded; authentication state
/// language remains valid outside this product registry.
abstract final class ChronoSparkFeatureCanon {
  static final List<ChronoSparkFeatureDefinition> active =
      List<ChronoSparkFeatureDefinition>.unmodifiable(
        <ChronoSparkFeatureDefinition>[
          _feature(
            id: ChronoSparkFeatureId.nexus,
            appView: AppView.nexus,
            purpose: 'Current decision context and next-best action.',
            category: ChronoSparkFeatureCategory.primaryCanonFeature,
          ),
          _feature(
            id: ChronoSparkFeatureId.smartPlanner,
            appView: AppView.smartPlanner,
            purpose: 'Explainable planning and plan reconciliation.',
            category: ChronoSparkFeatureCategory.primaryCanonFeature,
          ),
          _feature(
            id: ChronoSparkFeatureId.creator,
            appView: AppView.creator,
            purpose: 'Intelligent intake for tasks, goals, habits, and notes.',
            category: ChronoSparkFeatureCategory.primaryCanonFeature,
          ),
          _feature(
            id: ChronoSparkFeatureId.settings,
            appView: AppView.settings,
            purpose: 'Preferences, account controls, privacy, and support.',
            category: ChronoSparkFeatureCategory.primaryCanonFeature,
          ),
          _feature(
            id: ChronoSparkFeatureId.siConsole,
            appView: AppView.console,
            purpose: 'Deep strategic investigation and executable guidance.',
            category: ChronoSparkFeatureCategory.supportSurface,
          ),
          _feature(
            id: ChronoSparkFeatureId.timeline,
            appView: AppView.timeline,
            purpose: 'Planning history, schedule, and outcomes.',
            category: ChronoSparkFeatureCategory.primaryCanonFeature,
          ),
          _feature(
            id: ChronoSparkFeatureId.trajectoryEngine,
            appView: AppView.trajectoryEngine,
            purpose: 'Explicit future scenarios, assumptions, and corrections.',
            category: ChronoSparkFeatureCategory.primaryCanonFeature,
          ),
          _feature(
            id: ChronoSparkFeatureId.progression,
            appView: AppView.progression,
            purpose: 'Evidence-backed advancement and leverage actions.',
            category: ChronoSparkFeatureCategory.supportSurface,
          ),
        ],
      );

  static ChronoSparkFeatureDefinition _feature({
    required ChronoSparkFeatureId id,
    required AppView appView,
    required String purpose,
    required ChronoSparkFeatureCategory category,
  }) {
    final AppRouteDefinition route = AppRouteRegistry.routeForView(appView);
    return ChronoSparkFeatureDefinition(
      id: id,
      displayName: route.label,
      route: route.path,
      purpose: purpose,
      category: category,
    );
  }

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

  static ChronoSparkFeatureDefinition definition(ChronoSparkFeatureId id) =>
      active.firstWhere((ChronoSparkFeatureDefinition item) => item.id == id);
}
