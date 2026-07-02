class SiDecisionEntity {
  const SiDecisionEntity({
    this.selectedTaskId,
    required this.rationale,
    this.shouldTakeBreak = false,
    this.orderedTaskIds = const <String>[],
    this.recommendedFocusMinutes = 25,
  });

  final String? selectedTaskId;
  final String rationale;
  final bool shouldTakeBreak;
  final List<String> orderedTaskIds;
  final int recommendedFocusMinutes;
}
