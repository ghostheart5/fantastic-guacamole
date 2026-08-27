import 'package:fantastic_guacamole/domain/usecases/assemble_si_decision_output.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const AssembleSiDecisionOutput assemble = AssembleSiDecisionOutput();

  SiDecisionDraft build({
    bool friction = false,
    bool overwhelm = false,
    bool goalDrift = false,
    bool taskAvoidance = false,
    bool emotionalStrain = false,
    bool emotionalStability = false,
    String emotion = 'calm',
    int timelineHealthScore = 90,
    int timelineRiskScore = 10,
    int timelineOverdueCount = 0,
    int timelineUpcomingCount = 0,
    int timelineRiskEventsCount = 0,
    int timelineRecommendationCount = 0,
    String? nextTaskTitle,
    String? firstTaskTitle,
    int taskCount = 0,
    bool planPreviewIsEmpty = false,
    bool hasMemories = false,
    String memoryHint = 'No memory context.',
    int streak = 0,
    int activeHabitCount = 0,
  }) {
    return assemble(
      friction: friction,
      overwhelm: overwhelm,
      goalDrift: goalDrift,
      taskAvoidance: taskAvoidance,
      emotionalStrain: emotionalStrain,
      emotionalStability: emotionalStability,
      emotion: emotion,
      timelineHealthScore: timelineHealthScore,
      timelineRiskScore: timelineRiskScore,
      timelineOverdueCount: timelineOverdueCount,
      timelineUpcomingCount: timelineUpcomingCount,
      timelineRiskEventsCount: timelineRiskEventsCount,
      timelineRecommendationCount: timelineRecommendationCount,
      nextTaskTitle: nextTaskTitle,
      firstTaskTitle: firstTaskTitle,
      taskCount: taskCount,
      planPreviewIsEmpty: planPreviewIsEmpty,
      hasMemories: hasMemories,
      memoryHint: memoryHint,
      streak: streak,
      activeHabitCount: activeHabitCount,
    );
  }

  test('stable evidence produces the default action and planning prompts', () {
    final SiDecisionDraft draft = build(
      emotionalStability: true,
      timelineUpcomingCount: 1,
      timelineRecommendationCount: 1,
      planPreviewIsEmpty: true,
      timelineHealthScore: 92,
      timelineRiskScore: 8,
      streak: 2,
    );

    expect(draft.warnings, isEmpty);
    expect(draft.nextAction, 'Capture one high-value task.');
    expect(draft.suggestedPlanAdjustments, <String>[
      'Generate a 3-block adaptive plan for today.',
    ]);
    expect(draft.signalPrompts, <String>[
      'How can you convert this stable state into one decisive action?',
      'What is the next timeline deadline this week?',
      'What timeline recommendation should be applied now?',
    ]);
    expect(
      draft.progressionFeedback,
      'Rebuild momentum with one immediate win.',
    );
    expect(
      draft.plannerMessage,
      'Timeline is stable (health 92%). Execute the ranked next action and '
      'use the result to update the plan. No memory context.',
    );
  });

  test('pressure evidence produces all matching warnings and adjustments', () {
    final SiDecisionDraft draft = build(
      friction: true,
      overwhelm: true,
      goalDrift: true,
      taskAvoidance: true,
      emotionalStrain: true,
      emotion: 'anxious',
      timelineHealthScore: 65,
      timelineRiskScore: 71,
      timelineOverdueCount: 1,
      timelineUpcomingCount: 5,
      timelineRiskEventsCount: 2,
      firstTaskTitle: 'Review the launch checklist',
      taskCount: 6,
      hasMemories: true,
      streak: 4,
      activeHabitCount: 1,
    );

    expect(draft.warnings, <String>[
      'Overwhelm risk is elevated.',
      'Goal drift detected in recent trajectory.',
      'Task avoidance pattern detected.',
      'Emotional strain detected (anxious).',
      'Timeline has 1 overdue item.',
      'Timeline risk signals active (2).',
      'Timeline health is 65% with elevated risk 71%.',
    ]);
    expect(draft.nextAction, 'Review the launch checklist');
    expect(draft.suggestedPlanAdjustments, <String>[
      'Reduce today to one critical task block.',
      'Split remaining tasks into tomorrow queue.',
      'Resolve one overdue timeline item before adding new commitments.',
      'Pre-plan upcoming deadlines now to prevent rollover pressure.',
      'Protect 1 active habit alongside your task blocks.',
    ]);
    expect(draft.signalPrompts, <String>[
      'What is creating the most friction right now?',
      'Which goal has drifted and why?',
      'What would reduce emotional load in the next hour?',
      'What memory should inform this decision?',
      'Which overdue timeline item should be recovered first?',
      'What is the next timeline deadline this week?',
    ]);
    expect(
      draft.progressionFeedback,
      'Consistency is building. Keep the chain alive today.',
    );
    expect(
      draft.plannerMessage,
      'Current evidence shows pressure (timeline risk 71%). Reduce load or '
      'resolve the highest-ranked constraint before adding work.',
    );
  });

  test(
    'explicit next task wins and plural output is grammatically correct',
    () {
      final SiDecisionDraft draft = build(
        timelineOverdueCount: 2,
        nextTaskTitle: 'Ship the verified build',
        firstTaskTitle: 'This should not win',
        taskCount: 2,
        streak: 7,
        activeHabitCount: 2,
      );

      expect(draft.nextAction, 'Ship the verified build');
      expect(draft.warnings, contains('Timeline has 2 overdue items.'));
      expect(
        draft.suggestedPlanAdjustments,
        contains('Protect 2 active habits alongside your task blocks.'),
      );
      expect(
        draft.progressionFeedback,
        'Streak momentum is strong. Protect it with one decisive completion.',
      );
    },
  );

  test('missing task titles retain the safe capture fallback', () {
    final SiDecisionDraft draft = build(taskCount: 1);

    expect(draft.nextAction, 'Capture one high-value task.');
  });
}
