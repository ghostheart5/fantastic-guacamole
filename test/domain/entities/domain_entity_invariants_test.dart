import 'package:fantastic_guacamole/domain/entities/calendar_entry_entity.dart';
import 'package:fantastic_guacamole/domain/entities/entitlement.dart';
import 'package:fantastic_guacamole/domain/entities/learning_entity.dart';
import 'package:fantastic_guacamole/domain/entities/memory_entity.dart';
import 'package:fantastic_guacamole/domain/entities/notification_entity.dart';
import 'package:fantastic_guacamole/domain/entities/plan_entity.dart';
import 'package:fantastic_guacamole/domain/entities/project_entity.dart';
import 'package:fantastic_guacamole/domain/entities/si_state_entity.dart';
import 'package:fantastic_guacamole/domain/entities/subtask_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/entities/time_block.dart';
import 'package:fantastic_guacamole/domain/entities/work_window_entity.dart';
import 'package:fantastic_guacamole/domain/entities/workspace_entity.dart';
import 'package:fantastic_guacamole/domain/strategic/strategic_decision_contract.dart';
import 'package:fantastic_guacamole/domain/trajectory/trajectory_consequence_contract.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('domain entity invariants', () {
    test(
      'task snapshots copy subtasks and expose deterministic transitions',
      () {
        final List<String> source = <String>['sub-1'];
        final TaskEntity task = TaskEntity(
          id: 'task-1',
          title: 'Ship safely',
          createdAt: DateTime.utc(2026, 8, 29),
          subtasks: source,
        );
        source.add('sub-2');

        expect(task.subtasks, <String>['sub-1']);
        expect(() => task.subtasks.add('sub-3'), throwsUnsupportedError);

        final DateTime completedAt = DateTime.utc(2026, 8, 29, 10);
        final TaskEntity completed = task.complete(at: completedAt);
        completed.validate();
        expect(completed.completedAt, completedAt);
        expect(completed.updatedAt, completedAt);

        final DateTime canceledAt = DateTime.utc(2026, 8, 29, 11);
        final TaskEntity canceled = completed.cancel(at: canceledAt);
        canceled.validate();
        expect(canceled.isCanceled, isTrue);
        expect(canceled.completedAt, isNull);
        expect(canceled.updatedAt, canceledAt);
      },
    );

    test('subtask reopening clears completion state', () {
      final DateTime completedAt = DateTime.utc(2026, 8, 29, 10);
      final SubtaskEntity completed = SubtaskEntity(
        id: 'sub-1',
        parentTaskId: 'task-1',
        title: 'Verify',
        createdAt: DateTime.utc(2026, 8, 29),
      ).complete(at: completedAt);

      final SubtaskEntity reopened = completed.reopen(
        at: DateTime.utc(2026, 8, 29, 11),
      );
      expect(reopened.status, SubtaskStatus.pending);
      expect(reopened.completedAt, isNull);
    });

    test('corrupt persisted timestamps never become the current time', () {
      final ProjectEntity project = ProjectEntity.fromJson(<String, dynamic>{
        'id': 'project-1',
        'name': 'Project',
        'createdAt': 'invalid',
      });
      final SubtaskEntity subtask = SubtaskEntity.fromJson(<String, dynamic>{
        'id': 'sub-1',
        'parentTaskId': 'task-1',
        'title': 'Subtask',
        'createdAt': 'invalid',
      });

      expect(project.createdAt, DateTime.fromMillisecondsSinceEpoch(0));
      expect(subtask.createdAt, DateTime.fromMillisecondsSinceEpoch(0));
      expect(
        () => WorkWindowEntity.fromJson(<String, dynamic>{
          'id': 'window-1',
          'start': 'invalid',
          'end': 'also-invalid',
        }),
        throwsFormatException,
      );
    });

    test('plan and strategic request copy caller-owned collections', () {
      final TimeBlock block = TimeBlock(
        id: 'block-1',
        taskId: 'task-1',
        title: 'Focus',
        start: DateTime.utc(2026, 8, 29, 9),
        end: DateTime.utc(2026, 8, 29, 10),
      );
      final List<TimeBlock> blocks = <TimeBlock>[block];
      final PlanEntity plan = PlanEntity(
        id: 'plan-1',
        date: DateTime.utc(2026, 8, 29),
        blocks: blocks,
      );
      blocks.clear();
      expect(plan.blocks, <TimeBlock>[block]);
      expect(() => plan.blocks.clear(), throwsUnsupportedError);

      final List<TaskEntity> tasks = <TaskEntity>[
        TaskEntity(id: 'task-1', title: 'Focus'),
      ];
      final StrategicDecisionRequest request = StrategicDecisionRequest(
        state: SiStateEntity(energy: .5, attention: .5, fatigue: .2),
        tasks: tasks,
        createdAt: DateTime.utc(2026, 8, 29),
      );
      tasks.clear();
      expect(request.tasks, hasLength(1));
      expect(() => request.tasks.clear(), throwsUnsupportedError);
    });

    test('trajectory nodes copy caller-owned identifiers', () {
      final List<String> linkedTaskIds = <String>['task-1'];
      final TrajectoryGoalNode goal = TrajectoryGoalNode(
        id: 'goal-1',
        title: 'Launch',
        linkedTaskIds: linkedTaskIds,
      );
      linkedTaskIds.clear();

      expect(goal.linkedTaskIds, <String>['task-1']);
      expect(() => goal.linkedTaskIds.clear(), throwsUnsupportedError);
    });

    test('calendar corruption fails instead of inventing a current time', () {
      expect(
        () => CalendarEntryEntity.fromJson(<String, dynamic>{
          'id': 'entry-1',
          'title': 'Invalid',
          'start': 'bad',
          'end': 'bad',
        }),
        throwsFormatException,
      );
    });

    test('time-sensitive entities accept an explicit reference time', () {
      final DateTime reference = DateTime.utc(2026, 8, 29, 12);
      final Entitlement entitlement = Entitlement(
        featureId: 'planner',
        isEntitled: true,
        source: 'test',
        expiresAt: reference.add(const Duration(minutes: 1)),
      );
      final NotificationEntity notification = NotificationEntity(
        id: 'notification-1',
        title: 'Start',
        message: 'Begin now',
        scheduledAt: reference.add(const Duration(minutes: 5)),
      );

      expect(entitlement.isExpiredAt(reference), isFalse);
      expect(entitlement.hasAccessAt(reference), isTrue);
      expect(notification.isDueAt(reference), isFalse);
      expect(notification.timeUntilAt(reference), const Duration(minutes: 5));
    });

    test('learning, memory, and workspace copy caller-owned collections', () {
      final Map<String, double> affinity = <String, double>{'task-1': .8};
      final LearningEntity learning = LearningEntity(taskAffinity: affinity);
      affinity.clear();
      expect(learning.taskAffinity, <String, double>{'task-1': .8});
      expect(
        () => learning.taskAffinity['task-2'] = .5,
        throwsUnsupportedError,
      );

      final List<String> tags = <String>['manual'];
      final MemoryEntity memory = MemoryEntity(
        id: 'memory-1',
        text: 'Preference',
        date: DateTime.utc(2026, 8, 29),
        tags: tags,
      );
      tags.clear();
      expect(memory.tags, <String>['manual']);

      final Map<String, String> metadata = <String, String>{'mode': 'focus'};
      final WorkspaceEntity workspace = WorkspaceEntity(
        id: 'workspace-1',
        name: 'Primary',
        updatedAt: DateTime.utc(2026, 8, 29),
        metadata: metadata,
      );
      metadata.clear();
      expect(workspace.metadata, <String, String>{'mode': 'focus'});
    });
  });
}
