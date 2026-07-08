class AssistantResponseTemplates {
  const AssistantResponseTemplates._();

  static String smartCoachBlock({
    required String insight,
    required List<String> actions,
    required String nextStep,
    required String followUp,
    required double energy,
  }) {
    final String actionLines = actions.map((String item) => '• $item').join('\n');
    final int pct = (energy * 100).round();
    return '$insight\n\n'
        '$actionLines\n\n'
        'Next step: $nextStep\n\n'
        'Momentum score: +5 if completed today\n\n'
        '$followUp\n\n'
        'Energy: $pct%';
  }

  static String smartCoachFollowUp({
    required String move,
    required String question,
    required double energy,
  }) {
    final int pct = (energy * 100).round();
    return 'Try this next: $move\n\n'
        'Coach question: $question\n\n'
        'Momentum: +5 if you do it now.\n'
        'Energy: $pct%';
  }

  static String siAnalysis({
    required String query,
    required String category,
    required int goalsCount,
    required int openTasks,
    required int overdue,
    required String priorityTask,
    required String impact,
    required String timelineEffect,
    required List<String> nextActions,
    required int confidence,
  }) {
    final List<String> normalizedActions = List<String>.from(nextActions);
    while (normalizedActions.length < 3) {
      normalizedActions.add(
        normalizedActions.isEmpty
            ? 'Review priorities'
            : normalizedActions.length == 1
            ? 'Check timeline risks'
            : 'Create next task',
      );
    }

    return '🧠 SI ANALYSIS\n\n'
        'Query\n'
        '$query\n\n'
        'Intent Category\n'
        '$category\n\n'
        'Current State\n'
        '• $goalsCount active goals\n'
        '• $openTasks open tasks\n'
        '• $overdue overdue items\n\n'
        'Priority Task\n'
        '✅ $priorityTask\n\n'
        'Impact\n'
        '$impact\n\n'
        'Timeline Effect\n'
        '$timelineEffect\n\n'
        'Next Actions\n'
        '1. ${normalizedActions[0]}\n'
        '2. ${normalizedActions[1]}\n'
        '3. ${normalizedActions[2]}\n\n'
        'Confidence\n'
        '$confidence%';
  }
}
