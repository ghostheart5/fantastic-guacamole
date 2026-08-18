import 'package:fantastic_guacamole/app/router/route_paths.dart';
import 'package:fantastic_guacamole/domain/models/chronospark_feature_id.dart';

export 'package:fantastic_guacamole/domain/models/chronospark_feature_id.dart'
    show ChronoSparkFeatureId;

enum ChronoSparkFeatureStatus { active, compatibilityOnly, removed }

class ChronoSparkFeatureDefinition {
  const ChronoSparkFeatureDefinition({
    required this.id,
    required this.displayName,
    required this.route,
    required this.purpose,
    this.status = ChronoSparkFeatureStatus.active,
  });

  final ChronoSparkFeatureId id;
  final String displayName;
  final String route;
  final String purpose;
  final ChronoSparkFeatureStatus status;
}

/// The single production feature registry for user-facing names and routes.
///
/// Compatibility paths live in [RoutePaths] but must never be generated from
/// this registry. Insight is an output of Smart Planner or SI Console, not a
/// feature. Product Focus/Session is removed; authentication-session language
/// remains valid outside this product registry.
abstract final class ChronoSparkFeatureCanon {
  static const List<ChronoSparkFeatureDefinition> active =
      <ChronoSparkFeatureDefinition>[
        ChronoSparkFeatureDefinition(
          id: ChronoSparkFeatureId.nexus,
          displayName: 'Nexus',
          route: RoutePaths.nexus,
          purpose: 'Current operating state and next-best action.',
        ),
        ChronoSparkFeatureDefinition(
          id: ChronoSparkFeatureId.smartPlanner,
          displayName: 'Smart Planner',
          route: RoutePaths.smartPlanner,
          purpose: 'Explainable planning and plan reconciliation.',
        ),
        ChronoSparkFeatureDefinition(
          id: ChronoSparkFeatureId.creator,
          displayName: 'Creator',
          route: RoutePaths.creator,
          purpose: 'Intelligent intake for tasks, goals, habits, and notes.',
        ),
        ChronoSparkFeatureDefinition(
          id: ChronoSparkFeatureId.siConsole,
          displayName: 'SI Console',
          route: RoutePaths.siConsole,
          purpose: 'Deep strategic investigation and executable guidance.',
        ),
        ChronoSparkFeatureDefinition(
          id: ChronoSparkFeatureId.timeline,
          displayName: 'Timeline',
          route: RoutePaths.timeline,
          purpose: 'Operational history, schedule, and execution.',
        ),
        ChronoSparkFeatureDefinition(
          id: ChronoSparkFeatureId.trajectoryEngine,
          displayName: 'Trajectory Engine',
          route: RoutePaths.trajectoryEngine,
          purpose: 'Explicit future scenarios, assumptions, and corrections.',
        ),
        ChronoSparkFeatureDefinition(
          id: ChronoSparkFeatureId.progression,
          displayName: 'Progression',
          route: RoutePaths.progression,
          purpose: 'Evidence-backed advancement and leverage actions.',
        ),
      ];

  static const Set<String> prohibitedStandaloneProductTerms = <String>{
    'Session',
    'Focus',
    'Insight',
    'Insights',
    'Coach',
    'Flowmap',
  };

  static ChronoSparkFeatureDefinition definition(ChronoSparkFeatureId id) =>
      active.firstWhere((ChronoSparkFeatureDefinition item) => item.id == id);
}
