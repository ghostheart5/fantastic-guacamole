import 'package:fantastic_guacamole/data/services/ai/models/agent_result.dart';
import 'package:fantastic_guacamole/domain/entities/milestone_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/engine/learning/learning_history.dart';
import 'package:fantastic_guacamole/engine/si/ai_personality.dart';
import 'package:fantastic_guacamole/engine/si/si_response_policy.dart';
import 'package:fantastic_guacamole/state/controllers/ai_controller.dart';
import 'package:fantastic_guacamole/state/models/ai_recommendation.dart';
import 'package:fantastic_guacamole/state/models/task_view.dart';
import 'package:fantastic_guacamole/state/providers/milestones_provider.dart';
import 'package:fantastic_guacamole/state/providers/task_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('nextActionTextProvider falls back when there are no tasks', () {
    final ProviderContainer container = ProviderContainer(
      overrides: [
        tasksProvider.overrideWith((Ref ref) async => const <Task>[]),
      ],
    );
    addTearDown(container.dispose);

    expect(
      container.read(nextActionTextProvider),
      'Create your first task to get started.',
    );
  });

  test('nextActionTextProvider uses first ranked task title', () async {
    final ProviderContainer container = ProviderContainer(
      overrides: [
        tasksProvider.overrideWith((Ref ref) async {
          return <Task>[
            Task(
              id: 't1',
              title: 'Lock release scope',
              priority: 5,
              difficulty: 3,
              energyRequired: 3,
            ),
          ];
        }),
      ],
    );
    addTearDown(container.dispose);

    await container.read(tasksProvider.future);
    expect(
      container.read(nextActionTextProvider),
      'Work on: Lock release scope',
    );
  });

  test('AI notifier providers update state deterministically', () {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(aiTriggerProvider.notifier).set(7);
    container
        .read(aiPersonalityProvider.notifier)
        .set(AIPersonality.strategist);
    container.read(aiInputProvider.notifier).set('What is next?');
    container
        .read(aiExecutionStatusProvider.notifier)
        .set(
          const AIExecutionStatus(
            phase: 'running',
            requestId: 'req-1',
            durationMs: 55,
          ),
        );

    expect(container.read(aiTriggerProvider), 7);
    expect(container.read(aiPersonalityProvider), AIPersonality.strategist);
    expect(container.read(aiInputProvider), 'What is next?');
    expect(container.read(aiExecutionStatusProvider).phase, 'running');
  });

  test('sendMessage returns null for empty input', () async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    final AIController controller = container.read(aiControllerProvider);
    final result = await controller.sendMessage('   ');

    expect(result, isNull);
  });

  test('SI query routing classifies every production surface and intent', () {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    final AIController controller = container.read(aiControllerProvider);

    expect(
      controller.detectQuerySurfacesForTesting(
        'Task XP goal signal log memory notification plan energy timeline '
        'milestones trajectory',
      ),
      containsAll(<String>[
        'tasks',
        'progression',
        'goals',
        'signals',
        'logs',
        'memories',
        'notifications',
        'plan',
        'emotions',
        'timeline',
        'milestones',
        'trajectory',
      ]),
    );
    expect(
      controller.detectQuerySurfacesForTesting(
        'unclassified question',
        forcedSurface: 'goals',
      ),
      <String>['goals'],
    );
    expect(
      controller.detectQuerySurfacesForTesting('unclassified question'),
      <String>['general'],
    );

    expect(
      controller.deriveConsoleIntentForTesting(<String>['plan']),
      'planning',
    );
    expect(
      controller.deriveConsoleIntentForTesting(<String>['tasks']),
      'recommendation',
    );
    expect(
      controller.deriveConsoleIntentForTesting(<String>['timeline']),
      'summarization',
    );
    expect(
      controller.deriveConsoleIntentForTesting(<String>['general']),
      'chat',
    );

    const Map<String, String> categories = <String, String>{
      'system status': 'System Status',
      'next milestone': 'Milestone Query',
      'my goal': 'Goal Query',
      'open tasks': 'Task Query',
      'project roadmap': 'Project Query',
      'behind schedule': 'Timeline Query',
      'how am i doing': 'Progress Query',
      'what should I do': 'Recommendation Query',
      'what next': 'Priority Query',
      'analyze metrics': 'Analytics Query',
      'remember this': 'Memory Query',
      'summarize my life': 'Life Query',
    };
    for (final MapEntry<String, String> entry in categories.entries) {
      expect(
        controller.detectSIIntentCategoryForTesting(
          entry.key,
          const <String>[],
        ),
        entry.value,
        reason: entry.key,
      );
    }
    expect(
      controller.detectSIIntentCategoryForTesting('plain', <String>['goals']),
      'Goal Query',
    );
    expect(
      controller.detectSIIntentCategoryForTesting('plain', <String>['tasks']),
      'Task Query',
    );
    expect(
      controller.detectSIIntentCategoryForTesting('plain', <String>[
        'timeline',
      ]),
      'Timeline Query',
    );
    expect(
      controller.detectSIIntentCategoryForTesting('plain', <String>[
        'milestones',
      ]),
      'Milestone Query',
    );
    expect(
      controller.detectSIIntentCategoryForTesting('plain', <String>[
        'trajectory',
      ]),
      'Analytics Query',
    );
    expect(
      controller.detectSIIntentCategoryForTesting('plain', <String>[
        'memories',
      ]),
      'Memory Query',
    );
    expect(
      controller.detectSIIntentCategoryForTesting('plain', <String>[
        'progression',
      ]),
      'Progress Query',
    );
    expect(
      controller.detectSIIntentCategoryForTesting('plain', <String>['general']),
      'Recommendation Query',
    );
  });

  test(
    'deterministic SI responses expose grounded state and safe fallbacks',
    () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);
      final AIController controller = container.read(aiControllerProvider);
      final DateTime now = DateTime.utc(2026, 9, 3, 12);
      final TimelineEventEntity deadline = TimelineEventEntity(
        id: 'deadline',
        type: TimelineEventType.deadline,
        title: 'Ship candidate',
        detail: 'Release gate',
        timestamp: now,
        dueAt: now.add(const Duration(days: 1)),
      );
      final TimelineEventEntity milestoneEvent = TimelineEventEntity(
        id: 'milestone-event',
        type: TimelineEventType.milestone,
        title: 'Coverage gate',
        detail: 'Target reached',
        timestamp: now.subtract(const Duration(days: 1)),
      );

      expect(
        controller.timelineResponseForTesting(
          input: 'hello',
          matchedSurfaces: const <String>['general'],
          category: 'Recommendation Query',
          timelineEvents: const <TimelineEventEntity>[],
          timelineUpcomingEvents: const <TimelineEventEntity>[],
          timelineOverdueCount: 0,
          timelineUpcomingCount: 0,
          timelineHealthScore: 80,
          timelineRiskScore: 10,
          timelineRiskEventsCount: 0,
          timelineRecommendationCount: 0,
        ),
        isNull,
      );
      final timeline = controller.timelineResponseForTesting(
        input: 'timeline health',
        forcedSurface: 'timeline',
        matchedSurfaces: const <String>['timeline'],
        category: 'Timeline Query',
        timelineEvents: <TimelineEventEntity>[milestoneEvent],
        timelineUpcomingEvents: <TimelineEventEntity>[deadline],
        timelineOverdueCount: 1,
        timelineUpcomingCount: 1,
        timelineHealthScore: 50,
        timelineRiskScore: 75,
        timelineRiskEventsCount: 2,
        timelineRecommendationCount: 1,
      );
      expect(timeline?.reasoning, 'si_console_timeline_deterministic');
      expect(timeline?.message, contains('Ship candidate'));
      expect(timeline?.message, contains('At Risk'));

      expect(
        controller.trajectoryResponseForTesting(
          input: 'hello',
          matchedSurfaces: const <String>['general'],
          category: 'Recommendation Query',
          pressure: 10,
          momentum: .9,
          divergence: 5,
        ),
        isNull,
      );
      final trajectory = controller.trajectoryResponseForTesting(
        input: 'trajectory pressure',
        forcedSurface: 'trajectory',
        matchedSurfaces: const <String>['trajectory'],
        category: 'Analytics Query',
        pressure: 80,
        momentum: .3,
        divergence: 60,
      );
      expect(trajectory?.reasoning, 'si_console_trajectory_deterministic');
      expect(trajectory?.message, contains('No prediction available'));
      expect(trajectory?.message, contains('Impact: High'));

      final MilestoneEntity milestone = MilestoneEntity(
        id: 'm1',
        title: 'Closed-test readiness',
        priority: MilestonePriority.critical,
        createdAt: now,
        updatedAt: now,
      );
      final MilestoneSummary summary = MilestoneSummary(
        total: 1,
        active: 1,
        completed: 0,
        overdue: 1,
        upcoming: 0,
        healthScore: 45,
        momentumScore: 30,
        riskScore: 80,
        completionRate: 0,
        nextMilestone: milestone,
        closestMilestone: milestone,
        highestPriority: milestone,
      );
      expect(
        controller.milestoneResponseForTesting(
          input: 'hello',
          matchedSurfaces: const <String>['general'],
          category: 'Recommendation Query',
          summary: summary,
          milestones: <MilestoneEntity>[milestone],
          risks: const <MilestoneRisk>[],
          overdue: const <MilestoneEntity>[],
          upcoming: const <MilestoneEntity>[],
        ),
        isNull,
      );
      final milestoneResponse = controller.milestoneResponseForTesting(
        input: 'milestone health',
        forcedSurface: 'milestones',
        matchedSurfaces: const <String>['milestones'],
        category: 'Milestone Query',
        summary: summary,
        milestones: <MilestoneEntity>[milestone],
        risks: <MilestoneRisk>[
          MilestoneRisk(
            milestone: milestone,
            reason: 'No recent progress',
            recommendation: 'Protect one work block',
            daysBehind: 2,
            riskWeight: 80,
          ),
        ],
        overdue: <MilestoneEntity>[milestone],
        upcoming: const <MilestoneEntity>[],
      );
      expect(
        milestoneResponse?.reasoning,
        'si_console_milestone_deterministic',
      );
      expect(milestoneResponse?.message, contains('No recent progress'));

      final TaskEntity task = TaskEntity(
        id: 't1',
        title: 'Repair coverage',
        createdAt: now.subtract(const Duration(days: 1)),
        scheduledFor: now.subtract(const Duration(hours: 1)),
        priority: 5,
      );
      final fallback = controller.structuredFallbackForTesting(
        query: 'what next',
        category: 'Timeline Query',
        tasks: <TaskEntity>[task],
        goalsCount: 1,
        timelineOverdueCount: 2,
        timelineUpcomingCount: 1,
        timelineHealthScore: 40,
        timelineRiskScore: 80,
      );
      expect(fallback.reasoning, 'si_console_structured_fallback');
      expect(fallback.message, contains('Repair coverage'));
      expect(fallback.message, contains('Impact\nHigh'));
      expect(
        controller.isStructuredSIResponseForTesting(
          'SI ANALYSIS query current state next actions confidence',
        ),
        isTrue,
      );
      expect(
        controller.isStructuredSIResponseForTesting('plain answer'),
        isFalse,
      );
      final contract = controller.responseContractForTesting(
        'timeline',
        <String>['timeline', 'milestones'],
      );
      expect(contract['maxActions'], 3);
      expect(contract['grounding'], 'featureSnapshot_only');
    },
  );

  test('SI memory and novelty helpers preserve bounded grounded behavior', () {
    final DateTime now = DateTime.utc(2026, 9, 3, 12);
    final List<LearningHistoryEntry> skipHistory = <LearningHistoryEntry>[
      for (int index = 0; index < 2; index += 1)
        LearningHistoryEntry(
          timestamp: now.subtract(Duration(hours: index)),
          type: LearningEventType.skipped,
          difficulty: 3,
          effortWeight: 1,
          priorityWeight: 1,
          completed: 0,
          skipped: 1,
        ),
    ];
    expect(
      recentSkipPressureForTesting(const <LearningHistoryEntry>[]),
      isFalse,
    );
    expect(recentSkipPressureForTesting(skipHistory), isTrue);
    expect(
      aiCreditCostForTesting(
        input: 'short',
        personality: AIPersonality.strategist,
      ),
      1,
    );
    expect(
      aiCreditCostForTesting(
        input: 'x' * 121,
        personality: AIPersonality.strict,
      ),
      3,
    );

    final List<Task> tasks = <Task>[
      Task(
        id: 'primary',
        title: 'Primary task',
        priority: 5,
        difficulty: 3,
        energyRequired: 3,
      ),
      Task(
        id: 'alternative',
        title: 'Alternative task',
        priority: 4,
        difficulty: 2,
        energyRequired: 2,
      ),
    ];
    const AIRecommendation base = AIRecommendation(
      message: 'Do the primary task.',
      task: TaskView(
        id: 'primary',
        title: 'Primary task',
        priority: 5,
        difficulty: 3,
        energyRequired: 3,
      ),
      confidence: .8,
    );
    final alternatives = alternativeCandidatesForTesting(
      base: base,
      tasks: tasks,
    );
    expect(alternatives.single.taskId, 'alternative');
    expect(
      alternativeCandidatesForTesting(
        base: base,
        tasks: tasks.take(1).toList(),
      ),
      isEmpty,
    );

    const SIIntent taskIntent = SIIntent(
      label: 'task_recommendation',
      confidence: .8,
    );
    const SIIntent energyIntent = SIIntent(
      label: 'energy_check',
      confidence: .8,
    );
    const SIIntent statusIntent = SIIntent(label: 'status', confidence: .8);
    expect(
      leastRepeatedSafeFallbackForTesting(
        intent: taskIntent,
        tasks: const <Task>[],
        recentResponseHashes: const <String>[],
        recentResponseSummaries: const <String>[],
      ),
      contains('task'),
    );
    expect(
      leastRepeatedSafeFallbackForTesting(
        intent: energyIntent,
        tasks: tasks,
        recentResponseHashes: const <String>[],
        recentResponseSummaries: const <String>[],
      ),
      contains('energy'),
    );
    expect(
      leastRepeatedSafeFallbackForTesting(
        intent: statusIntent,
        tasks: tasks,
        recentResponseHashes: const <String>[],
        recentResponseSummaries: const <String>[],
      ),
      isNotEmpty,
    );
    expect(
      classifyMemoryTypeForTesting(intent: taskIntent, recommendation: base),
      'task_recommendation',
    );
    expect(
      classifyMemoryTypeForTesting(
        intent: energyIntent,
        recommendation: const AIRecommendation(message: 'Energy response'),
      ),
      'energy_signal',
    );
    expect(
      classifyMemoryTypeForTesting(
        intent: statusIntent,
        recommendation: const AIRecommendation(message: 'Status response'),
      ),
      'status_summary',
    );
    expect(
      summarizeInteractionForTesting(
        input: 'What should I do next with all of these release tasks?',
        output: 'Repair measured coverage and verify the target gate.',
      ),
      startsWith('Q:'),
    );

    final List<Map<String, dynamic>> events = appendMemoryEventForTesting(
      previousState: <String, dynamic>{
        'memoryEvents': <Map<String, dynamic>>[
          for (int index = 0; index < 120; index += 1)
            <String, dynamic>{'id': index},
        ],
      },
      memoryEvent: <String, dynamic>{'id': 120},
    );
    expect(events, hasLength(120));
    expect(events.first['id'], 1);
    expect(events.last['id'], 120);
    expect(
      appendMemoryEventForTesting(
        previousState: null,
        memoryEvent: <String, dynamic>{'id': 1},
      ),
      hasLength(1),
    );

    final List<Map<String, String>> history = <Map<String, String>>[
      for (int index = 0; index < 22; index += 1)
        <String, String>{'role': 'user', 'content': 'message $index'},
    ];
    final summarized = summarizeHistoryForTesting(history);
    expect(summarized, hasLength(20));
    expect(summarized.first['content'], 'message 2');

    final AgentResult validTaskResult = AgentResult(
      selectedAgent: 'planning',
      workflow: 'execute',
      payload: <String, dynamic>{
        'message': 'Use the alternative task.',
        'task': tasks.last.toJson(),
        'confidence': .75,
        'emotion': 'balanced',
        'source': 'local',
      },
    );
    final response = responseFromAgentResultForTesting(
      result: validTaskResult,
      tasks: tasks,
      personality: AIPersonality.planner,
    );
    expect(response.taskTitle, 'Alternative task');
    expect(response.action, 'recommend_task');

    final invalidTaskResponse = responseFromAgentResultForTesting(
      result: AgentResult(
        selectedAgent: 'planning',
        workflow: 'execute',
        payload: <String, dynamic>{
          'message': 'No grounded task.',
          'task': <String, dynamic>{
            ...tasks.last.toJson(),
            'id': 'not-available',
          },
        },
      ),
      tasks: tasks,
      personality: AIPersonality.strategist,
    );
    expect(invalidTaskResponse.taskTitle, isNull);
    expect(invalidTaskResponse.action, 'respond_conversationally');
  });
}
