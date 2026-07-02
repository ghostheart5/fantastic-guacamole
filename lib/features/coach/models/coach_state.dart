class CoachState {
  const CoachState({
    required this.recommendation,
    required this.reason,
    required this.canStartFocus,
  });

  final String recommendation;
  final String reason;
  final bool canStartFocus;

  CoachState copyWith({
    String? recommendation,
    String? reason,
    bool? canStartFocus,
  }) {
    return CoachState(
      recommendation: recommendation ?? this.recommendation,
      reason: reason ?? this.reason,
      canStartFocus: canStartFocus ?? this.canStartFocus,
    );
  }
}
