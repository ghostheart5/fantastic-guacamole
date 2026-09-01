import 'package:fantastic_guacamole/app/router/route_paths.dart';
import 'package:fantastic_guacamole/domain/operating_system/operating_system_contract.dart';

enum NexusDecisionStatus { loading, ready, partial, offline, error }

class NexusDecisionModel {
  const NexusDecisionModel({
    required this.status,
    required this.isOnline,
    required this.pendingSyncCount,
    required this.topRisk,
    required this.recentProgress,
    required this.statusDetail,
    this.intelligence,
  });

  final NexusDecisionStatus status;
  final bool isOnline;
  final int pendingSyncCount;
  final DecisionIntelligence? intelligence;
  final String topRisk;
  final String recentProgress;
  final String statusDetail;

  bool get hasDecisionIntelligence => intelligence != null;

  bool get isEmpty =>
      intelligence?.snapshot.actionableCount == 0 &&
      intelligence?.snapshot.activeGoalCount == 0;

  String get statusLabel => switch (status) {
    NexusDecisionStatus.loading => 'LINKING',
    NexusDecisionStatus.ready => 'READY',
    NexusDecisionStatus.partial => 'PARTIAL',
    NexusDecisionStatus.offline => 'OFFLINE',
    NexusDecisionStatus.error => 'RECOVERY NEEDED',
  };

  String get attentionLabel {
    final OperatingSnapshot? snapshot = intelligence?.snapshot;
    if (snapshot == null) return 'Evaluating decision context';
    return 'Momentum ${snapshot.momentum}% • Pressure ${snapshot.pressure}%';
  }

  DateTime? get evaluatedAt => intelligence?.snapshot.observedAt;
}

enum NexusActionDestination {
  creatorTask,
  creatorNote,
  goals,
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
      OperatingActionType.openCreator => NexusActionDestination.creatorTask,
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
      OperatingActionType.acknowledgeDecision =>
        NexusActionDestination.acknowledge,
      OperatingActionType.none => NexusActionDestination.none,
      OperatingActionType.openEntity => _fromCanonicalRoute(intent.destination),
    };
  }

  static NexusActionDestination _fromCanonicalRoute(String destination) {
    return switch (destination) {
      RoutePaths.creator => NexusActionDestination.creatorTask,
      RoutePaths.creatorGoals => NexusActionDestination.goals,
      RoutePaths.timeline => NexusActionDestination.timeline,
      RoutePaths.smartPlanner => NexusActionDestination.smartPlanner,
      RoutePaths.siConsole => NexusActionDestination.siConsole,
      RoutePaths.trajectoryEngine => NexusActionDestination.trajectoryEngine,
      RoutePaths.progression => NexusActionDestination.progression,
      _ => NexusActionDestination.unsupported,
    };
  }
}
