import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/milestone_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task.dart';
import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/state/providers/goals_provider.dart';
import 'package:fantastic_guacamole/state/providers/milestones_provider.dart';
import 'package:fantastic_guacamole/state/providers/task_provider.dart';
import 'package:fantastic_guacamole/state/providers/timeline_provider.dart';
import 'package:fantastic_guacamole/state/providers/si_v2_provider.dart';
import 'package:fantastic_guacamole/state/services/si_v2_read_gateway.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'cached SI counts refresh after source mutations in the same session',
    () async {
      final goals = <GoalEntity>[];
      var reads = 0;
      final container = ProviderContainer(
        overrides: [
          tasksProvider.overrideWith((ref) async => <Task>[]),
          goalsProvider.overrideWith(_Goals.new),
          milestonesProvider.overrideWith(_Milestones.new),
          timelineProvider.overrideWith(_Timeline.new),
          siV2ReadGatewayProvider.overrideWithValue(
            SIV2ReadGateway(
              accountScopeId: 'account:demo',
              readTasks: () async {
                reads++;
                return [];
              },
              readGoals: () async => List.of(goals),
              readMilestones: () async => [],
              readTimeline: () async => [],
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        siV2EvidenceSnapshotProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      await container.read(tasksProvider.future);
      await container.read(milestonesProvider.future);
      final before = await container.read(siV2EvidenceSnapshotProvider.future);
      expect(before.goals, isEmpty);
      goals.add(
        GoalEntity(
          id: 'new',
          title: 'A newly saved goal',
          createdAt: DateTime.utc(2026, 9, 8),
        ),
      );
      (container.read(goalsProvider.notifier) as _Goals).replace(goals);
      final after = await container.read(siV2EvidenceSnapshotProvider.future);
      expect(after.goals.single.title, 'A newly saved goal');
      expect(after.revision, isNot(before.revision));
      for (final invalidate in <void Function()>[
        () => container.invalidate(tasksProvider),
        () => container.invalidate(milestonesProvider),
        () => container.invalidate(timelineProvider),
      ]) {
        final previousReads = reads;
        invalidate();
        await container.read(siV2EvidenceSnapshotProvider.future);
        expect(reads, greaterThan(previousReads));
      }
    },
  );
}

class _Goals extends GoalsNotifier {
  @override
  List<GoalEntity> build() => [];
  void replace(List<GoalEntity> goals) => state = List.of(goals);
}

class _Milestones extends MilestonesNotifier {
  @override
  Future<List<MilestoneEntity>> build() async => [];
}

class _Timeline extends TimelineNotifier {
  @override
  List<TimelineEventEntity> build() => [];
}
