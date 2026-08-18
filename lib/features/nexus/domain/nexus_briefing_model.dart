import 'package:fantastic_guacamole/app/feature_canon.dart';
import 'package:fantastic_guacamole/app/router/route_paths.dart';
import 'package:fantastic_guacamole/domain/operating_system/operating_system_contract.dart';

enum NexusBriefingStatus { loading, ready, partial, offline, error }

enum NexusFeatureHealth { loading, ready, empty, degraded, unavailable }

class NexusFeatureSignal {
  const NexusFeatureSignal({
    required this.featureId,
    required this.health,
    required this.headline,
    required this.detail,
    required this.revision,
  });

  final ChronoSparkFeatureId featureId;
  final NexusFeatureHealth health;
  final String headline;
  final String detail;
  final String revision;

  ChronoSparkFeatureDefinition get definition =>
      ChronoSparkFeatureCanon.definition(featureId);
}

class NexusBriefingModel {
  const NexusBriefingModel({
    required this.status,
    required this.isOnline,
    required this.pendingSyncCount,
    required this.featureSignals,
    required this.topRisk,
    required this.recentProgress,
    required this.statusDetail,
    this.briefing,
  });

  final NexusBriefingStatus status;
  final bool isOnline;
  final int pendingSyncCount;
  final OperatingBriefing? briefing;
  final List<NexusFeatureSignal> featureSignals;
  final String topRisk;
  final String recentProgress;
  final String statusDetail;

  bool get hasAuthoritativeBriefing => briefing != null;

  bool get isEmpty =>
      briefing?.snapshot.actionableCount == 0 &&
      briefing?.snapshot.activeGoalCount == 0;

  String get statusLabel => switch (status) {
    NexusBriefingStatus.loading => 'LINKING',
    NexusBriefingStatus.ready => 'READY',
    NexusBriefingStatus.partial => 'PARTIAL',
    NexusBriefingStatus.offline => 'OFFLINE',
    NexusBriefingStatus.error => 'RECOVERY NEEDED',
  };

  String get attentionLabel {
    final OperatingSnapshot? snapshot = briefing?.snapshot;
    if (snapshot == null) return 'Evaluating operating state';
    return 'Momentum ${snapshot.momentum}% • Pressure ${snapshot.pressure}%';
  }

  DateTime? get evaluatedAt => briefing?.snapshot.observedAt;
}

enum NexusActionDestination {
  creator,
  timeline,
  smartPlanner,
  siConsole,
  trajectoryEngine,
  progression,
  acknowledge,
  none,
  unsupported,
}

abstract final class NexusActionResolver {
  static NexusActionDestination resolve(OperatingActionIntent intent) {
    return switch (intent.type) {
      OperatingActionType.openCreator => NexusActionDestination.creator,
      OperatingActionType.openTimeline ||
      OperatingActionType.createTimelineBlock ||
      OperatingActionType.rescheduleCommitment =>
        NexusActionDestination.timeline,
      OperatingActionType.openSmartPlanner ||
      OperatingActionType.reprioritizeGoal =>
        NexusActionDestination.smartPlanner,
      OperatingActionType.openSiConsole => NexusActionDestination.siConsole,
      OperatingActionType.openTrajectoryEngine =>
        NexusActionDestination.trajectoryEngine,
      OperatingActionType.openProgression => NexusActionDestination.progression,
      OperatingActionType.acknowledgeBriefing =>
        NexusActionDestination.acknowledge,
      OperatingActionType.none => NexusActionDestination.none,
      OperatingActionType.openEntity => _fromCanonicalRoute(intent.destination),
    };
  }

  static NexusActionDestination _fromCanonicalRoute(String destination) {
    return switch (destination) {
      RoutePaths.creator ||
      RoutePaths.creatorTasks ||
      RoutePaths.creatorGoals ||
      RoutePaths.creatorHabits ||
      RoutePaths.creatorNotes => NexusActionDestination.creator,
      RoutePaths.timeline => NexusActionDestination.timeline,
      RoutePaths.smartPlanner => NexusActionDestination.smartPlanner,
      RoutePaths.siConsole => NexusActionDestination.siConsole,
      RoutePaths.trajectoryEngine => NexusActionDestination.trajectoryEngine,
      RoutePaths.progression => NexusActionDestination.progression,
      _ => NexusActionDestination.unsupported,
    };
  }
}
