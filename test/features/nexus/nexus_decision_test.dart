import 'package:fantastic_guacamole/app/router/route_paths.dart';
import 'package:fantastic_guacamole/domain/operating_system/operating_system_contract.dart';
import 'package:fantastic_guacamole/features/nexus/domain/nexus_decision_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps every typed decision action without a silent fallback', () {
    const Map<OperatingActionType, NexusActionDestination>
    expected = <OperatingActionType, NexusActionDestination>{
      OperatingActionType.openEntity: NexusActionDestination.siConsole,
      OperatingActionType.openCreator: NexusActionDestination.creatorTask,
      OperatingActionType.openTimeline: NexusActionDestination.timeline,
      OperatingActionType.openSmartPlanner: NexusActionDestination.smartPlanner,
      OperatingActionType.openSiConsole: NexusActionDestination.siConsole,
      OperatingActionType.openTrajectoryEngine:
          NexusActionDestination.trajectoryEngine,
      OperatingActionType.openProgression: NexusActionDestination.progression,
      OperatingActionType.createTimelineBlock: NexusActionDestination.timeline,
      OperatingActionType.rescheduleCommitment: NexusActionDestination.timeline,
      OperatingActionType.reprioritizeGoal: NexusActionDestination.smartPlanner,
      OperatingActionType.acknowledgeDecision:
          NexusActionDestination.acknowledge,
      OperatingActionType.none: NexusActionDestination.none,
    };

    for (final MapEntry<OperatingActionType, NexusActionDestination> entry
        in expected.entries) {
      expect(
        NexusActionResolver.resolve(
          OperatingActionIntent(
            id: entry.key.name,
            type: entry.key,
            label: entry.key.name,
            destination: entry.key == OperatingActionType.openEntity
                ? RoutePaths.siConsole
                : RoutePaths.nexus,
          ),
        ),
        entry.value,
      );
    }
  });

  test('rejects an unknown entity route', () {
    expect(
      NexusActionResolver.resolve(
        const OperatingActionIntent(
          id: 'unknown',
          type: OperatingActionType.openEntity,
          label: 'Unknown',
          destination: '/not-canonical',
        ),
      ),
      NexusActionDestination.unsupported,
    );
  });

  test('resolves Creator and Goals routes without conflating them', () {
    expect(
      NexusActionResolver.resolve(
        const OperatingActionIntent(
          id: 'task',
          type: OperatingActionType.openEntity,
          label: 'Task',
          destination: RoutePaths.creator,
        ),
      ),
      NexusActionDestination.creatorTask,
    );
    expect(
      NexusActionResolver.resolve(
        const OperatingActionIntent(
          id: 'goal',
          type: OperatingActionType.openEntity,
          label: 'Goal',
          destination: RoutePaths.creatorGoals,
        ),
      ),
      NexusActionDestination.goals,
    );
  });

  test(
    'model reports real decision state without feature-card projections',
    () {
      const NexusDecisionModel model = NexusDecisionModel(
        status: NexusDecisionStatus.ready,
        isOnline: true,
        pendingSyncCount: 0,
        topRisk: 'No material constraint is supported yet.',
        recentProgress: 'No prior snapshot.',
        statusDetail: 'Ready',
      );

      expect(model.statusLabel, 'READY');
      expect(model.hasDecisionIntelligence, isFalse);
      expect(model.attentionLabel, 'Evaluating decision context');
    },
  );
}
