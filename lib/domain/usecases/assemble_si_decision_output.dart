/// Draft SI decision output, produced from already-derived signals and counts.
///
/// The state layer maps this onto its own `SIDecisionOutput` view model.
class SiDecisionDraft {
  const SiDecisionDraft({
    required this.nextAction,
    required this.plannerMessage,
    required this.suggestedPlanAdjustments,
    required this.signalPrompts,
    required this.progressionFeedback,
    required this.warnings,
  });

  final String nextAction;
  final String plannerMessage;
  final List<String> suggestedPlanAdjustments;
  final List<String> signalPrompts;
  final String progressionFeedback;
  final List<String> warnings;
}

/// CHRONOSPARK-CLASS: SHIPPING | Feature: SI Console
///
/// Builds the SI Console decision output: warnings, next action, plan
/// adjustments, signal prompts, progression feedback and the planner message.
///
/// This previously lived inline in `si_pipeline_provider`, which made the
/// provider the owner of the decision rules rather than an orchestrator. Inputs
/// are primitives so the domain layer stays independent of state-layer models.
class AssembleSiDecisionOutput {
  const AssembleSiDecisionOutput();

  /// Timeline health below this is called out as a warning.
  static const int healthWarningThreshold = 70;

  /// Task count above this suggests deferring work.
  static const int taskOverflowThreshold = 5;

  SiDecisionDraft call({
    required bool friction,
    required bool overwhelm,
    required bool goalDrift,
    required bool taskAvoidance,
    required bool emotionalStrain,
    required bool emotionalStability,
    required String emotion,
    required int timelineHealthScore,
    required int timelineRiskScore,
    required int timelineOverdueCount,
    required int timelineUpcomingCount,
    required int timelineRiskEventsCount,
    required int timelineRecommendationCount,
    required String? nextTaskTitle,
    required String? firstTaskTitle,
    required int taskCount,
    required bool planPreviewIsEmpty,
    required bool hasMemories,
    required String memoryHint,
    required int streak,
    required int activeHabitCount,
  }) {
    final List<String> warnings = <String>[
      if (overwhelm) 'Overwhelm risk is elevated.',
      if (goalDrift) 'Goal drift detected in recent trajectory.',
      if (taskAvoidance) 'Task avoidance pattern detected.',
      if (emotionalStrain) 'Emotional strain detected ($emotion).',
      if (timelineOverdueCount > 0)
        'Timeline has $timelineOverdueCount overdue item${timelineOverdueCount == 1 ? '' : 's'}.',
      if (timelineRiskEventsCount > 0)
        'Timeline risk signals active ($timelineRiskEventsCount).',
      if (timelineHealthScore < healthWarningThreshold)
        'Timeline health is $timelineHealthScore% with elevated risk $timelineRiskScore%.',
    ];

    final String nextAction =
        nextTaskTitle ??
        (taskCount == 0
            ? 'Capture one high-value task.'
            : (firstTaskTitle ?? 'Capture one high-value task.'));

    final List<String> planAdjustments = <String>[
      if (overwhelm) 'Reduce today to one critical task block.',
      if (taskCount > taskOverflowThreshold)
        'Split remaining tasks into tomorrow queue.',
      if (planPreviewIsEmpty) 'Generate a 3-block adaptive plan for today.',
      if (timelineOverdueCount > 0)
        'Resolve one overdue timeline item before adding new commitments.',
      if (timelineUpcomingCount >= 5)
        'Pre-plan upcoming deadlines now to prevent rollover pressure.',
      if (activeHabitCount > 0)
        'Protect $activeHabitCount active habit${activeHabitCount == 1 ? '' : 's'} alongside your task blocks.',
    ];

    final List<String> signalPrompts = <String>[
      if (friction) 'What is creating the most friction right now?',
      if (goalDrift) 'Which goal has drifted and why?',
      if (emotionalStrain) 'What would reduce emotional load in the next hour?',
      if (emotionalStability)
        'How can you convert this stable state into one decisive action?',
      if (hasMemories) 'What memory should inform this decision?',
      if (timelineOverdueCount > 0)
        'Which overdue timeline item should be recovered first?',
      if (timelineUpcomingCount > 0)
        'What is the next timeline deadline this week?',
      if (timelineRecommendationCount > 0)
        'What timeline recommendation should be applied now?',
    ];

    final String progressionFeedback = streak >= 7
        ? 'Streak momentum is strong. Protect it with one decisive completion.'
        : streak >= 3
        ? 'Consistency is building. Keep the chain alive today.'
        : 'Rebuild momentum with one immediate win.';

    final String plannerMessage = warnings.isEmpty
        ? 'Timeline is stable (health $timelineHealthScore%). Execute the ranked next action and use the result to update the plan. $memoryHint'
        : 'Current evidence shows pressure (timeline risk $timelineRiskScore%). Reduce load or resolve the highest-ranked constraint before adding work.';

    return SiDecisionDraft(
      nextAction: nextAction,
      plannerMessage: plannerMessage,
      suggestedPlanAdjustments: planAdjustments,
      signalPrompts: signalPrompts,
      progressionFeedback: progressionFeedback,
      warnings: warnings,
    );
  }
}
