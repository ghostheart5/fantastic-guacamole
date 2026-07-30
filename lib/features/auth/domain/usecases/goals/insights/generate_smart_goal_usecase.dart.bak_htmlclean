class SmartGoalDraft {
  const SmartGoalDraft({
    required this.title,
    required this.specific,
    required this.measurable,
    required this.achievable,
    required this.relevant,
    required this.timeBound,
    required this.summary,
  });

  final String title;
  final String specific;
  final String measurable;
  final String achievable;
  final String relevant;
  final String timeBound;
  final String summary;
}

class GenerateSmartGoalUsecase {
  const GenerateSmartGoalUsecase();

  SmartGoalDraft call({
    required String title,
    String? context,
    DateTime? targetDate,
  }) {
    final String normalizedTitle = title.trim().isEmpty
        ? 'Build a clear goal'
        : title.trim();

    final String normalizedContext = context?.trim().isEmpty ?? true
        ? 'No extra context provided.'
        : context!.trim();

    final String timeBound = targetDate == null
        ? 'Choose a target date or weekly review checkpoint.'
        : 'Complete by ${targetDate.toIso8601String()}.';

    return SmartGoalDraft(
      title: normalizedTitle,
      specific: 'Define exactly what "$normalizedTitle" means in one sentence.',
      measurable:
          'Track progress using tasks, checkpoints, or completion count.',
      achievable:
          'Break the goal into small actions that can be completed consistently.',
      relevant: normalizedContext,
      timeBound: timeBound,
      summary:
          'SMART Goal: $normalizedTitle. Specific, measurable, achievable, relevant, and time-bound.',
    );
  }
}
