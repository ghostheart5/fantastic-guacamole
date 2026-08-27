/// CHRONOSPARK-CLASS: SHIPPING | Feature: SI Console
///
/// Must leave the domain only via SiPolicy.sanitize.
class SiDecisionEntity {
  const SiDecisionEntity({
    this.selectedTaskId,
    required this.rationale,
    this.shouldTakeBreak = false,
    this.orderedTaskIds = const <String>[],
    this.recommendedExecutionMinutes = 25,
    this.action = '',
    this.tone = 'adaptive',
    this.shouldSimplify = false,
    this.reasoningTrace = '',
  });

  final String? selectedTaskId;
  final String rationale;
  final bool shouldTakeBreak;
  final List<String> orderedTaskIds;
  final int recommendedExecutionMinutes;

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
    int? recommendedExecutionMinutes,
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
      recommendedExecutionMinutes:
          recommendedExecutionMinutes ?? this.recommendedExecutionMinutes,
      action: action ?? this.action,
      tone: tone ?? this.tone,
      shouldSimplify: shouldSimplify ?? this.shouldSimplify,
      reasoningTrace: reasoningTrace ?? this.reasoningTrace,
    );
  }

  // Domain behavior
  bool get hasSelectedTask => selectedTaskId != null;

  bool get isBreakRecommendation => shouldTakeBreak && selectedTaskId == null;

  bool get hasOrderedTasks => orderedTaskIds.isNotEmpty;

  String? get firstTask =>
      orderedTaskIds.isNotEmpty ? orderedTaskIds.first : null;

  List<String> get remainingTasks =>
      orderedTaskIds.length <= 1 ? [] : orderedTaskIds.sublist(1);

  Duration get executionDuration =>
      Duration(minutes: recommendedExecutionMinutes);

  bool get isShortExecution => recommendedExecutionMinutes <= 15;
  bool get isLongExecution => recommendedExecutionMinutes >= 45;

  bool get hasReasoningTrace => reasoningTrace.trim().isNotEmpty;

  void validate() {
    if (shouldTakeBreak && selectedTaskId != null) {
      throw StateError(
        'Decision cannot recommend a break and a task at the same time',
      );
    }

    if (recommendedExecutionMinutes <= 0) {
      throw StateError('Execution minutes must be positive');
    }
  }
}
