import 'package:fantastic_guacamole/domain/entities/recurrence_rule.dart';
import 'package:fantastic_guacamole/domain/entities/task.dart';
import 'package:fantastic_guacamole/domain/entities/time_block.dart';
import 'package:fantastic_guacamole/domain/planning/planner_input.dart';
import 'package:fantastic_guacamole/domain/usecases/analyze_plan_context.dart';
import 'package:fantastic_guacamole/domain/usecases/generate_adaptive_plan.dart';
import 'package:fantastic_guacamole/domain/usecases/recommend_next_block.dart';
import 'package:fantastic_guacamole/engine/planning/calendar_service.dart';
import 'package:flutter_test/flutter_test.dart';

Task _task(
  String id, {
  int priority = 3,
  int difficulty = 3,
  int energyRequired = 3,
  DateTime? scheduledFor,
}) {
  return Task(
    id: id,
    title: 'Task $id',
    priority: priority,
    difficulty: difficulty,
    energyRequired: energyRequired,
    scheduledFor: scheduledFor,
    recurrenceRule: RecurrenceRule.none,
  );
}

void main() {
  group('GenerateAdaptivePlan', () {
    final DateTime start = DateTime(2026, 3, 2, 9);

    test('delegates to CalendarService without changing its output', () {
      final CalendarService service = CalendarService();
      final GenerateAdaptivePlan useCase = GenerateAdaptivePlan(service);
      final List<Task> tasks = <Task>[
        _task('a', priority: 5),
        _task('b', priority: 1),
      ];

      final List<TimeBlock> direct = service.generateAdaptivePlan(
        inputs: PlannerInputAdapter.fromLegacyTasks(tasks),
        energy: 0.6,
        startTime: start,
      );
      final List<TimeBlock> viaUseCase = useCase(
        inputs: PlannerInputAdapter.fromLegacyTasks(tasks),
        energy: 0.6,
        startTime: start,
      );

      expect(viaUseCase.length, direct.length);
      expect(
        viaUseCase.map((TimeBlock b) => b.taskId).toList(),
        direct.map((TimeBlock b) => b.taskId).toList(),
      );
    });

    test('returns an empty plan for no tasks', () {
      final GenerateAdaptivePlan useCase = GenerateAdaptivePlan(
        CalendarService(),
      );
      expect(useCase(inputs: const <PlannerInput>[], energy: 0.5), isEmpty);
    });

    test('ranks higher priority work first', () {
      final GenerateAdaptivePlan useCase = GenerateAdaptivePlan(
        CalendarService(),
      );
      final List<TimeBlock> blocks = useCase(
        inputs: PlannerInputAdapter.fromLegacyTasks(<Task>[
          _task('low', priority: 1),
          _task('high', priority: 5),
        ]),
        energy: 0.5,
        startTime: start,
      );

      expect(blocks.first.taskId, 'high');
    });

    test('applies explicit deadline and fixed-block planning policy', () {
      final GenerateAdaptivePlan useCase = GenerateAdaptivePlan(
        CalendarService(),
      );
      final List<TimeBlock> blocks = useCase(
        inputs: <PlannerInput>[
          const PlannerInput(
            id: 'high',
            title: 'High priority',
            priority: 4,
            difficulty: 3,
            energyRequired: 3,
            isCompleted: false,
            isCanceled: false,
            prerequisiteIds: <String>[],
            recurrenceRule: RecurrenceRule.none,
            estimatedDuration: Duration(minutes: 40),
          ),
          PlannerInput(
            id: 'deadline',
            title: 'Near deadline',
            priority: 2,
            difficulty: 2,
            energyRequired: 2,
            isCompleted: false,
            isCanceled: false,
            prerequisiteIds: const <String>[],
            recurrenceRule: RecurrenceRule.none,
            dueDate: start.add(const Duration(hours: 2)),
            estimatedDuration: const Duration(minutes: 20),
          ),
        ],
        energy: .9,
        startTime: start,
        policy: const AdaptivePlanPolicy(
          deadlineWeight: 3,
          adaptDurationToEnergy: false,
          fixedBreakMinutes: 10,
        ),
      );

      expect(blocks.first.taskId, 'deadline');
      expect(blocks.first.end.difference(blocks.first.start).inMinutes, 20);
      expect(
        blocks[1].start.difference(blocks.first.end),
        const Duration(minutes: 10),
      );
    });
  });

  group('AnalyzePlanContext', () {
    const AnalyzePlanContext analyze = AnalyzePlanContext();
    final DateTime start = DateTime(2026, 3, 2, 9);

    test('summarises an empty plan as empty with all tasks unplanned', () {
      final PlanContext context = analyze(
        blocks: const <TimeBlock>[],
        tasks: <Task>[_task('a'), _task('b')],
        energy: 0.5,
      );

      expect(context.isEmpty, isTrue);
      expect(context.blockCount, 0);
      expect(context.unplannedTaskCount, 2);
      expect(context.isOverloaded, isFalse);
    });

    test('counts blocks, minutes and planned days', () {
      final PlanContext context = analyze(
        blocks: <TimeBlock>[
          TimeBlock(
            id: '1',
            taskId: 'a',
            title: 'A',
            start: start,
            end: start.add(const Duration(minutes: 30)),
          ),
          TimeBlock(
            id: '2',
            taskId: 'b',
            title: 'B',
            start: start.add(const Duration(days: 1)),
            end: start.add(const Duration(days: 1, minutes: 45)),
          ),
        ],
        tasks: <Task>[_task('a'), _task('b'), _task('c')],
        energy: 0.5,
      );

      expect(context.blockCount, 2);
      expect(context.plannedMinutes, 75);
      expect(context.plannedDayCount, 2);
      expect(context.unplannedTaskCount, 1);
      expect(context.firstBlockStart, start);
    });

    test('flags a day past the overload threshold', () {
      final PlanContext context = analyze(
        blocks: <TimeBlock>[
          TimeBlock(
            id: '1',
            taskId: 'a',
            title: 'A',
            start: start,
            end: start.add(
              const Duration(
                minutes: AnalyzePlanContext.overloadedMinutesPerDay + 1,
              ),
            ),
          ),
        ],
        tasks: <Task>[_task('a')],
        energy: 0.5,
      );

      expect(context.isOverloaded, isTrue);
    });

    test('bands energy using the planner thresholds', () {
      List<TimeBlock> none() => const <TimeBlock>[];
      expect(
        analyze(blocks: none(), tasks: const <Task>[], energy: 0.9).energyBand,
        'high',
      );
      expect(
        analyze(blocks: none(), tasks: const <Task>[], energy: 0.5).energyBand,
        'steady',
      );
      expect(
        analyze(blocks: none(), tasks: const <Task>[], energy: 0.2).energyBand,
        'low',
      );
    });
  });

  group('RecommendNextBlock', () {
    const RecommendNextBlock recommend = RecommendNextBlock();
    final DateTime now = DateTime(2026, 3, 2, 10);

    TimeBlock block(String id, DateTime start, Duration length) {
      return TimeBlock(
        id: id,
        taskId: id,
        title: id,
        start: start,
        end: start.add(length),
      );
    }

    test('returns null for an empty plan', () {
      expect(recommend(blocks: const <TimeBlock>[], now: now), isNull);
    });

    test('prefers the block currently in progress', () {
      final TimeBlock active = block(
        'active',
        now.subtract(const Duration(minutes: 5)),
        const Duration(minutes: 30),
      );
      final TimeBlock later = block(
        'later',
        now.add(const Duration(hours: 2)),
        const Duration(minutes: 30),
      );

      expect(
        recommend(blocks: <TimeBlock>[later, active], now: now)?.id,
        'active',
      );
    });

    test('otherwise returns the earliest upcoming block', () {
      final TimeBlock soon = block(
        'soon',
        now.add(const Duration(minutes: 30)),
        const Duration(minutes: 30),
      );
      final TimeBlock later = block(
        'later',
        now.add(const Duration(hours: 3)),
        const Duration(minutes: 30),
      );

      expect(recommend(blocks: <TimeBlock>[later, soon], now: now)?.id, 'soon');
    });

    test('returns null when the whole plan is in the past', () {
      final TimeBlock past = block(
        'past',
        now.subtract(const Duration(hours: 3)),
        const Duration(minutes: 30),
      );

      expect(recommend(blocks: <TimeBlock>[past], now: now), isNull);
    });
  });
}
