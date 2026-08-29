import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task.dart';
import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/features/timeline/logic/timeline_projection.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final DateTime now = DateTime.utc(2026, 8, 29, 12);

  test('projects only active tasks and goals that still need attention', () {
    final List<TimelineEventEntity> events = projectTimelineEvents(
      now: now,
      tasks: <Task>[
        _task('active', now.add(const Duration(days: 1))),
        _task(
          'completed',
          now.subtract(const Duration(days: 1)),
          isCompleted: true,
        ),
        _task(
          'skipped',
          now.subtract(const Duration(days: 1)),
          isSkipped: true,
        ),
        _task(
          'canceled',
          now.subtract(const Duration(days: 1)),
          isCanceled: true,
        ),
      ],
      goals: <GoalEntity>[
        _goal('active-goal', now.add(const Duration(days: 2))),
        _goal(
          'completed-goal',
          now.subtract(const Duration(days: 1)),
          completedAt: now,
        ),
      ],
    );

    expect(events.map((event) => event.id), <String>[
      'timeline-projected-task-active',
      'timeline-projected-goal-active-goal',
    ]);
  });
}

Task _task(
  String id,
  DateTime dueDate, {
  bool isCompleted = false,
  bool isSkipped = false,
  bool isCanceled = false,
}) => Task(
  id: id,
  title: id,
  priority: 3,
  difficulty: 2,
  energyRequired: 2,
  dueDate: dueDate,
  isCompleted: isCompleted,
  isSkipped: isSkipped,
  isCanceled: isCanceled,
);

GoalEntity _goal(String id, DateTime targetDate, {DateTime? completedAt}) =>
    GoalEntity(
      id: id,
      title: id,
      createdAt: DateTime.utc(2026, 1, 1),
      targetDate: targetDate,
      completedAt: completedAt,
    );
