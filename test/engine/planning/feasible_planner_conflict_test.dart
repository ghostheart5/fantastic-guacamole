import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/entities/time_block.dart';
import 'package:fantastic_guacamole/domain/entities/work_window_entity.dart';
import 'package:fantastic_guacamole/engine/planning/feasible_planner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 9, 14, 8);

  test('every retained overlap is reported and makes the plan infeasible', () {
    final plan = const FeasiblePlanner().plan(
      PlanningProblem(
        tasks: const <TaskEntity>[],
        workWindows: <WorkWindowEntity>[
          WorkWindowEntity(
            id: 'day',
            start: now,
            end: now.add(const Duration(hours: 8)),
          ),
        ],
        existingBlocks: <TimeBlock>[
          TimeBlock(
            id: 'long',
            taskId: 'a',
            title: 'Long',
            start: now,
            end: now.add(const Duration(hours: 4)),
          ),
          TimeBlock(
            id: 'short',
            taskId: 'b',
            title: 'Short',
            start: now.add(const Duration(hours: 1)),
            end: now.add(const Duration(hours: 2)),
          ),
          TimeBlock(
            id: 'later',
            taskId: 'c',
            title: 'Later',
            start: now.add(const Duration(hours: 3)),
            end: now.add(const Duration(hours: 5)),
          ),
        ],
        energy: .7,
        now: now,
      ),
    );
    expect(plan.blocks, hasLength(3));
    expect(
      plan.issues.where((issue) => issue.type == PlanIssueType.conflict),
      hasLength(2),
    );
    expect(plan.isFeasible, isFalse);
  });

  test('scheduled dependent task still reports its unmet prerequisite', () {
    final prerequisite = TaskEntity(
      id: 'first',
      title: 'First',
      createdAt: now,
    );
    final dependent = TaskEntity(
      id: 'second',
      title: 'Second',
      createdAt: now,
      subtasks: const <String>['first'],
    );
    final plan = const FeasiblePlanner().plan(
      PlanningProblem(
        tasks: <TaskEntity>[prerequisite, dependent],
        workWindows: <WorkWindowEntity>[
          WorkWindowEntity(
            id: 'day',
            start: now,
            end: now.add(const Duration(hours: 8)),
          ),
        ],
        existingBlocks: <TimeBlock>[
          TimeBlock(
            id: 'second-block',
            taskId: 'second',
            title: 'Second',
            start: now.add(const Duration(hours: 1)),
            end: now.add(const Duration(hours: 2)),
          ),
        ],
        energy: .7,
        now: now,
      ),
    );
    expect(plan.unscheduledTaskIds, contains('second'));
    expect(
      plan.issues.any(
        (issue) =>
            issue.type == PlanIssueType.dependencyBlocked &&
            issue.taskId == 'second',
      ),
      isTrue,
    );
    expect(plan.isFeasible, isFalse);
  });
}
