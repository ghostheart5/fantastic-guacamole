import 'package:fantastic_guacamole/domain/entities/si_state_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/entities/time_block.dart';
import 'package:fantastic_guacamole/domain/policies/progression_policy.dart';
import 'package:fantastic_guacamole/engine/learning/adaptive_learning.dart';
import 'package:fantastic_guacamole/engine/learning/learning_history.dart';
import 'package:fantastic_guacamole/engine/learning/learning_state.dart';
import 'package:fantastic_guacamole/engine/planning/calendar_service.dart';
import 'package:fantastic_guacamole/engine/scoring/session_scoring_engine.dart';
import 'package:fantastic_guacamole/engine/tasks/task_ranker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Learning and planning correctness guards', () {
    test('adaptive learning clamps weight updates and tracks counters', () {
      final LearningState start = const LearningState(
        effortWeight: 1.98,
        priorityWeight: 1.97,
        completed: 4,
        skipped: 1,
      );

      final LearningState completed = AdaptiveLearning(start).onTaskComplete(5);
      expect(completed.effortWeight, lessThanOrEqualTo(2.0));
      expect(completed.priorityWeight, lessThanOrEqualTo(2.0));
      expect(completed.completed, 5);

      final LearningState low = const LearningState(
        effortWeight: 0.51,
        priorityWeight: 0.51,
        completed: 0,
        skipped: 0,
      );
      final LearningState skipped = AdaptiveLearning(low).onTaskSkipped(5);
      expect(skipped.effortWeight, greaterThanOrEqualTo(0.5));
      expect(skipped.priorityWeight, greaterThanOrEqualTo(0.5));
      expect(skipped.skipped, 1);
    });

    test('learning history entry keeps immutable event metadata', () {
      final LearningHistoryEntry entry = LearningHistoryEntry(
        timestamp: DateTime.utc(2026, 7, 5, 10),
        type: LearningEventType.completed,
        difficulty: 4,
        effortWeight: 1.1,
        priorityWeight: 1.2,
        completed: 12,
        skipped: 3,
      );

      expect(entry.type, LearningEventType.completed);
      expect(entry.difficulty, 4);
      expect(entry.completed, 12);
      expect(entry.skipped, 3);
    });

    test('calendar service prioritizes higher-priority tasks in day plan', () {
      final CalendarService service = CalendarService();
      final DateTime start = DateTime.utc(2026, 7, 5, 9);

      final List<TimeBlock> plan = service.generateDayPlan(
        tasks: const <Task>[
          Task(
            id: 'low',
            title: 'Low',
            priority: 1,
            difficulty: 1,
            energyRequired: 1,
          ),
          Task(
            id: 'high',
            title: 'High',
            priority: 5,
            difficulty: 3,
            energyRequired: 3,
          ),
        ],
        startTime: start,
      );

      expect(plan.first.taskId, 'high');
      expect(plan.first.start, start);
      expect(plan.first.end.isBefore(plan[1].start), isTrue);
    });

    test(
      'low energy reduces workload intensity and favors lower-energy tasks',
      () {
        final CalendarService service = CalendarService();
        final DateTime start = DateTime.utc(2026, 7, 5, 9);

        final List<TimeBlock> lowEnergyPlan = service.generateAdaptivePlan(
          tasks: const <Task>[
            Task(
              id: 'overwhelm',
              title: 'Hard deep-work task',
              priority: 4,
              difficulty: 5,
              energyRequired: 5,
            ),
            Task(
              id: 'gentle',
              title: 'Low-friction setup task',
              priority: 3,
              difficulty: 1,
              energyRequired: 1,
            ),
          ],
          energy: 0.2,
          startTime: start,
        );

        expect(lowEnergyPlan.first.taskId, 'gentle');
        final Duration firstDuration = lowEnergyPlan.first.end.difference(
          lowEnergyPlan.first.start,
        );
        expect(firstDuration.inMinutes, greaterThanOrEqualTo(18));
        final Duration between = lowEnergyPlan[1].start.difference(
          lowEnergyPlan.first.end,
        );
        expect(between.inMinutes, 15);
      },
    );

    test('calendar service rejects overlapping time blocks', () {
      final CalendarService service = CalendarService();
      final DateTime day = DateTime.utc(2026, 7, 5);

      service.addTimeBlock(
        day,
        TimeBlock(
          id: 'a',
          taskId: 'task-a',
          title: 'A',
          start: DateTime.utc(2026, 7, 5, 9),
          end: DateTime.utc(2026, 7, 5, 10),
        ),
      );

      expect(
        () => service.addTimeBlock(
          day,
          TimeBlock(
            id: 'b',
            taskId: 'task-b',
            title: 'B',
            start: DateTime.utc(2026, 7, 5, 9, 30),
            end: DateTime.utc(2026, 7, 5, 10, 30),
          ),
        ),
        throwsStateError,
      );
    });

    test(
      'session scoring returns bounded quality, expected XP and feedback tiers',
      () {
        final SessionScoringEngine engine = SessionScoringEngine();

        final fast = engine.calculate(
          seconds: 30,
          energy: 0.6,
          taskPriority: 3,
        );
        final strong = engine.calculate(
          seconds: 300,
          energy: 0.7,
          taskPriority: 5,
        );

        expect(fast.xp, ProgressionPolicy.sessionXp);
        expect(strong.xp, ProgressionPolicy.sessionXp);
        expect(fast.quality, inInclusiveRange(0.0, 1.0));
        expect(strong.quality, inInclusiveRange(0.0, 1.0));
        expect(strong.feedback.toLowerCase(), contains('excellent'));
        expect(fast.feedback, isNotEmpty);
      },
    );

    test(
      'task ranker switches to ease-first mode when overwhelm avoidance is enabled',
      () {
        final List<TaskEntity> tasks = <TaskEntity>[
          TaskEntity(
            id: 'hard',
            title: 'Hard task',
            createdAt: DateTime.utc(2026, 7, 5),
            priority: 5,
            difficulty: 5,
            energyRequired: 5,
          ),
          TaskEntity(
            id: 'easy',
            title: 'Easy task',
            createdAt: DateTime.utc(2026, 7, 5),
            priority: 1,
            difficulty: 1,
            energyRequired: 1,
          ),
        ];

        final List<RankedTask> ranked = const TaskRanker().rank(
          tasks,
          learning: const LearningState(),
          energy: 0.3,
          fatigue: 0.8,
          siState: SiStateEntity(
            energy: 0.3,
            focus: 0.2,
            fatigue: 0.8,
            avoidOverwhelm: true,
          ),
        );

        expect(ranked.first.task.id, 'easy');
        expect(ranked.last.task.id, 'hard');
      },
    );
  });
}
