class SiDecisionEntity {
  const SiDecisionEntity({
    this.selectedTaskId,
    required this.rationale,
    this.shouldTakeBreak = false,
    this.orderedTaskIds = const <String>[],
    this.recommendedFocusMinutes = 25,
    this.action = '',
    this.tone = 'adaptive',
    this.shouldSimplify = false,
    this.reasoningTrace = '',
  });

  final String? selectedTaskId;
  final String rationale;
  final bool shouldTakeBreak;
  final List<String> orderedTaskIds;
  final int recommendedFocusMinutes;

  // Pipeline-aligned fields
  final String action;
  final String tone;
  final bool shouldSimplify;
  final String reasoningTrace;

  SiDecisionEntity copyWith({
    String? selectedTaskId,
    String? rationale,
    bool? shouldTakeBreak,
    List<String>? orderedTaskIds,
    int? recommendedFocusMinutes,
    String? action,
    String? tone,
    bool? shouldSimplify,
    String? reasoningTrace,
  }) {
    return SiDecisionEntity(
      selectedTaskId: selectedTaskId ?? this.selectedTaskId,
      rationale: rationale ?? this.rationale,
      shouldTakeBreak: shouldTakeBreak ?? this.shouldTakeBreak,
      orderedTaskIds: orderedTaskIds ?? this.orderedTaskIds,
      recommendedFocusMinutes:
          recommendedFocusMinutes ?? this.recommendedFocusMinutes,
      action: action ?? this.action,
      tone: tone ?? this.tone,
      shouldSimplify: shouldSimplify ?? this.shouldSimplify,
      reasoningTrace: reasoningTrace ?? this.reasoningTrace,
    );
  }
}
