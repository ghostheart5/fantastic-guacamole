import 'package:fantastic_guacamole/app/router/route_paths.dart';
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
  static const List<ChronoSparkFeatureDefinition> active =
      <ChronoSparkFeatureDefinition>[
        ChronoSparkFeatureDefinition(
          id: ChronoSparkFeatureId.nexus,
          displayName: 'Nexus',
          route: RoutePaths.nexus,
          purpose: 'Current decision context and next-best action.',
          category: ChronoSparkFeatureCategory.primaryCanonFeature,
        ),
        ChronoSparkFeatureDefinition(
          id: ChronoSparkFeatureId.smartPlanner,
          displayName: 'Smart Planner',
          route: RoutePaths.smartPlanner,
          purpose: 'Explainable planning and plan reconciliation.',
          category: ChronoSparkFeatureCategory.primaryCanonFeature,
        ),
        ChronoSparkFeatureDefinition(
          id: ChronoSparkFeatureId.creator,
          displayName: 'Creator',
          route: RoutePaths.creator,
          purpose: 'Intelligent intake for tasks, goals, habits, and notes.',
          category: ChronoSparkFeatureCategory.primaryCanonFeature,
        ),
        ChronoSparkFeatureDefinition(
          id: ChronoSparkFeatureId.settings,
          displayName: 'Settings',
          route: RoutePaths.settings,
          purpose: 'Preferences, account controls, privacy, and support.',
          category: ChronoSparkFeatureCategory.primaryCanonFeature,
        ),
        ChronoSparkFeatureDefinition(
          id: ChronoSparkFeatureId.siConsole,
          displayName: 'SI Console',
          route: RoutePaths.siConsole,
          purpose: 'Deep strategic investigation and executable guidance.',
          category: ChronoSparkFeatureCategory.supportSurface,
        ),
        ChronoSparkFeatureDefinition(
          id: ChronoSparkFeatureId.timeline,
          displayName: 'Timeline',
          route: RoutePaths.timeline,
          purpose: 'Planning history, schedule, and outcomes.',
          category: ChronoSparkFeatureCategory.primaryCanonFeature,
        ),
        ChronoSparkFeatureDefinition(
          id: ChronoSparkFeatureId.trajectoryEngine,
          displayName: 'Trajectory Engine',
          route: RoutePaths.trajectoryEngine,
          purpose: 'Explicit future scenarios, assumptions, and corrections.',
          category: ChronoSparkFeatureCategory.primaryCanonFeature,
        ),
        ChronoSparkFeatureDefinition(
          id: ChronoSparkFeatureId.progression,
          displayName: 'Progression',
          route: RoutePaths.progression,
          purpose: 'Evidence-backed advancement and leverage actions.',
          category: ChronoSparkFeatureCategory.supportSurface,
        ),
      ];

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
    'Insight',
    'Insights',
    'Co'
        'ach',
    'Flowmap',
  };

  static ChronoSparkFeatureDefinition definition(ChronoSparkFeatureId id) =>
      active.firstWhere((ChronoSparkFeatureDefinition item) => item.id == id);
}
