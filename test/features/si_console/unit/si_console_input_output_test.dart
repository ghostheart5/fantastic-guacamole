import 'package:fantastic_guacamole/domain/entities/completion_event_entity.dart';
import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/memory_entity.dart';
import 'package:fantastic_guacamole/domain/entities/routine_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task.dart';
import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/engine/assistant/assistant_context_builder.dart';
import 'package:fantastic_guacamole/engine/assistant/assistant_detection_service.dart';
import 'package:fantastic_guacamole/features/si_console/ui/models/si_response_frame.dart';
import 'package:fantastic_guacamole/state/controllers/ai_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('SI Console preserves task, habit, goal, and timeline context for a focus query', () {
    const String userInput = 'What should I focus on today?';
    final DateTime fixedNow = DateTime(2026, 8, 2, 9);

    final List<Task> tasks = <Task>[
      Task(
        id: 'task-1',
        title: 'Draft launch brief',
        priority: 5,
        difficulty: 3,
        energyRequired: 3,
        scheduledFor: fixedNow,
      ),
    ];
    final List<GoalEntity> goals = <GoalEntity>[
      GoalEntity(
        id: 'goal-1',
        title: 'Ship ChronoSpark beta',
        createdAt: fixedNow,
      ),
    ];
    final List<RoutineEntity> routines = <RoutineEntity>[
      RoutineEntity(
        id: 'habit-1',
        name: 'Daily review ritual',
        createdAt: fixedNow,
      ),
    ];
    final List<TimelineEventEntity> timeline = <TimelineEventEntity>[
      TimelineEventEntity(
        id: 'timeline-1',
        type: TimelineEventType.deadline,
        title: 'Beta rehearsal at 3 PM',
        detail: 'Prepare the launch demo flow.',
        timestamp: fixedNow,
        status: TimelineEventStatus.active,
        dueAt: fixedNow.add(const Duration(hours: 6)),
      ),
    ];
    final List<MemoryEntity> memories = <MemoryEntity>[
      MemoryEntity(
        id: 'memory-1',
        text: 'Launch prep works best when the daily review ritual happens first.',
        date: fixedNow,
        category: MemoryCategory.habit,
      ),
    ];
    final List<CompletionEventEntity> completions = <CompletionEventEntity>[
      CompletionEventEntity(
        id: 'completion-1',
        eventType: CompletionEventType.completed,
        eventAt: fixedNow.subtract(const Duration(days: 1)),
        taskId: 'task-0',
      ),
    ];

    final assistantIntent = const DefaultAssistantIntentDetector().detect(
      input: userInput,
      surface: 'si_console',
    );
    final DefaultAssistantContextBuilder contextBuilder =
        const DefaultAssistantContextBuilder();

    final List<String> timelineSummaries = summarizeTimelineTitles(timeline);
    final List<String> routineSummaries = summarizeRoutineNames(routines);
    final List<String> completionSummaries = summarizeCompletionEvents(completions);
    final List<String> scheduleSummaries = summarizeScheduledTaskTitles(tasks);
    final List<String> memorySummaries = memories.map((m) => m.text).toList();
    final Map<String, dynamic> chronosparkSignals = buildSIConsoleChronosparkSignals(
      profileName: 'Operator',
      profileLevel: 4,
      profileXp: 120,
      profileStreak: 6,
      progressionLevel: 4,
      progressionXp: 120,
      progressionStreak: 6,
      siEnergy: 0.72,
      siFatigue: 0.24,
      siCompletedToday: 1,
      trajectoryPressure: 42,
      trajectoryMomentum: 0.68,
      trajectoryDivergence: 18,
      trajectoryPrediction: 'Trajectory strengthens with focused execution.',
      completionEvents: completions,
      tasks: tasks,
      scheduledTasks: tasks,
      routines: routines,
      activeRoutines: routines,
    );

    final Map<String, dynamic> assistantContext = contextBuilder.buildSIConsoleContext(
      input: userInput,
      intent: assistantIntent,
      matchedSurfaces: const <String>['tasks', 'goals', 'plan'],
      memorySummaries: memorySummaries,
      timelineSummaries: timelineSummaries,
      taskCount: tasks.length,
      goalCount: goals.length,
    );

    final Map<String, dynamic> chronosparkModel =
        contextBuilder.buildChronosparkModelContext(
      surface: 'si_console',
      intent: assistantIntent,
      taskSummaries: tasks.map((t) => t.title).toList(),
      goalSummaries: goals.map((g) => g.title).toList(),
      timelineSummaries: timelineSummaries,
      memorySummaries: memorySummaries,
      completionSummaries: completionSummaries,
      routineSummaries: routineSummaries,
      scheduleSummaries: scheduleSummaries,
      signals: chronosparkSignals,
    );

    final Map<String, dynamic> groundedModel =
        chronosparkModel['grounded'] as Map<String, dynamic>;
    final List<String> groundedTasks =
        (groundedModel['tasks'] as List<dynamic>).cast<String>();
    final List<String> groundedRoutines =
        (groundedModel['routines'] as List<dynamic>).cast<String>();
    final List<String> groundedGoals =
        (groundedModel['goals'] as List<dynamic>).cast<String>();
    final List<String> assistantTimelineSummaries =
        (assistantContext['timelineSummaries'] as List<dynamic>).cast<String>();

    final String output = SIResponseFrame.build(
      evidence: <String>[
        'Task context: ${groundedTasks.join(' | ')}',
        'Habit context: ${groundedRoutines.join(' | ')}',
        'Goal context: ${groundedGoals.join(' | ')}',
        'Timeline context: ${assistantTimelineSummaries.join(' | ')}',
      ],
      recommendedMove:
          'Focus on Draft launch brief first, keep Daily review ritual intact, and use it to advance Ship ChronoSpark beta before Beta rehearsal at 3 PM.',
      confidenceSignal: SIResponseFrame.signalBandFromPercent(72),
    );

    expect((assistantContext['query'] as String), userInput);
    expect((assistantContext['taskCount'] as int), 1);
    expect((assistantContext['goalCount'] as int), 1);

    expect(groundedTasks, contains('Draft launch brief'));
    expect(groundedRoutines, contains('Daily review ritual'));
    expect(groundedGoals, contains('Ship ChronoSpark beta'));

    expect(output, isNotEmpty);
    expect(output, contains('Draft launch brief'));
    expect(output, contains('Daily review ritual'));
    expect(output, contains('Ship ChronoSpark beta'));
    expect(output, contains('Beta rehearsal at 3 PM'));
    expect(output, contains('NEXT MOVE'));
    expect(output, isNot(contains('I do not have a materially new grounded answer yet')));
    expect(output, isNot(contains('Create your first task to get started')));
  });
}