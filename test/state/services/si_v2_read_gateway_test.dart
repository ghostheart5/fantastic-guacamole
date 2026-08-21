import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/milestone_entity.dart';
import 'package:fantastic_guacamole/domain/entities/si_v2_contract.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/state/services/si_v2_read_gateway.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final DateTime now = DateTime.utc(2026, 8, 20, 12);

  test('maps only bounded read evidence and strips sensitive detail', () async {
    final SIV2ReadGateway gateway = SIV2ReadGateway(
      accountScopeId: 'account:test',
      readTasks: () async => <TaskEntity>[
        TaskEntity(
          id: 'task',
          title: 'Visible title',
          description: 'Retrieved text must not cross the SI V2 gateway.',
          createdAt: now,
        ),
      ],
      readGoals: () async => <GoalEntity>[
        GoalEntity(
          id: 'goal',
          title: 'Visible goal',
          description: 'Private goal detail',
          createdAt: now,
        ),
      ],
      readMilestones: () async => <MilestoneEntity>[
        MilestoneEntity(
          id: 'milestone',
          title: 'Visible milestone',
          note: 'Private milestone note',
          reflection: 'Private reflection',
          createdAt: now,
          updatedAt: now,
        ),
      ],
      readTimeline: () async => <TimelineEventEntity>[
        TimelineEventEntity(
          id: 'event',
          type: TimelineEventType.task,
          title: 'Visible event',
          detail: 'Private Timeline detail',
          timestamp: now,
        ),
      ],
    );

    final SIV2EvidenceSnapshot snapshot = await gateway.read(observedAt: now);

    expect(snapshot.tasks.single.title, 'Visible title');
    expect(snapshot.goals.single.title, 'Visible goal');
    expect(snapshot.milestones.single.title, 'Visible milestone');
    expect(snapshot.timeline.single.title, 'Visible event');
    final String rendered = <Object?>[
      snapshot.tasks.single.title,
      snapshot.goals.single.title,
      snapshot.milestones.single.title,
      snapshot.timeline.single.title,
    ].join(' ');
    expect(rendered, isNot(contains('Private')));
    expect(snapshot.unavailableSources, isEmpty);
  });

  test('source failure is explicit and does not block healthy reads', () async {
    final SIV2ReadGateway gateway = SIV2ReadGateway(
      accountScopeId: 'account:test',
      readTasks: () async => throw StateError('task read failed'),
      readGoals: () async => <GoalEntity>[
        GoalEntity(id: 'g', title: 'Goal', createdAt: now),
      ],
      readMilestones: () async => const <MilestoneEntity>[],
      readTimeline: () async => const <TimelineEventEntity>[],
    );

    final SIV2EvidenceSnapshot snapshot = await gateway.read(observedAt: now);

    expect(snapshot.tasks, isEmpty);
    expect(snapshot.goals, hasLength(1));
    expect(snapshot.unavailableSources, <SIV2Source>{SIV2Source.tasks});
  });
}
