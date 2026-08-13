import 'package:fantastic_guacamole/domain/entities/learning_entity.dart';
import 'package:fantastic_guacamole/domain/entities/si_state_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/entities/time_block.dart';
import 'package:fantastic_guacamole/domain/entities/work_window_entity.dart';
import 'package:fantastic_guacamole/domain/planning/planner_input.dart';
import 'package:fantastic_guacamole/engine/decision/decision_engine.dart';
import 'package:fantastic_guacamole/engine/planning/calendar_service.dart';
import 'package:fantastic_guacamole/engine/planning/feasible_planner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final DateTime now = DateTime.utc(2026, 8, 12, 9);
  final TaskEntity entity = TaskEntity(
    id: 'task-1',
    title: 'Write continuity test',
    createdAt: now,
    priority: 5,
    difficulty: 2,
    energyRequired: 2,
    estimatedDuration: const Duration(minutes: 25),
    scheduledFor: now,
    dueDate: now.add(const Duration(hours: 4)),
  );

  test('TaskEntity conversion preserves planning-relevant fields', () {
    final PlannerInput input = PlannerInputAdapter.fromTaskEntity(entity);

    expect(input.id, entity.id);
    expect(input.priority, entity.priority);
    expect(input.estimatedDuration, entity.estimatedDuration);
    expect(input.dueDate, entity.dueDate);
    expect(input.isCompleted, isFalse);
  });

  test('legacy Task has one explicit PlannerInput compatibility path', () {
    final PlannerInput input = PlannerInputAdapter.fromLegacyTask(Task(
      id: 'legacy-1',
      title: 'Legacy planner task',
      priority: 4,
      difficulty: 3,
      energyRequired: 3,
      scheduledFor: now,
    ));

    expect(input.id, 'legacy-1');
    expect(input.isCompleted, isFalse);
    expect(PlannerInputAdapter.toLegacyTask(input).title, input.title);
  });

  test('DecisionEngine and FeasiblePlanner consume PlannerInput', () {
    final PlannerInput input = PlannerInputAdapter.fromTaskEntity(entity);
    final List<WorkWindowEntity> windows = <WorkWindowEntity>[
      WorkWindowEntity(
        id: 'window',
        start: now,
        end: now.add(const Duration(hours: 2)),
      ),
    ];
    final FeasiblePlan plan = const FeasiblePlanner().plan(PlanningProblem(
      inputs: <PlannerInput>[input],
      workWindows: windows,
      existingBlocks: const [],
      energy: .8,
      now: now,
    ));
    final DecisionRecommendation decision = const DecisionEngine().recommend(
      inputs: <PlannerInput>[input],
      state: SiStateEntity(
        energy: .8,
        focus: .8,
        fatigue: .1,
        avoidOverwhelm: false,
        primaryInstinct: 'progress_first',
      ),
      learning: const LearningEntity(),
      workWindows: windows,
      now: now,
    );

    expect(plan.blocks.single.taskId, entity.id);
    expect(decision.selectedTask?.id, entity.id);
    expect(decision.plan.blocks.single.title, entity.title);
  });

  test('Calendar Smart Planner projection consumes PlannerInput', () {
    final List<TimeBlock> blocks = CalendarService().generateAdaptivePlan(
      inputs: <PlannerInput>[PlannerInputAdapter.fromTaskEntity(entity)],
      energy: .8,
      startTime: now,
    );

    expect(blocks.single.taskId, entity.id);
  });
}
