class SIState {
  const SIState({
    this.energy = 0.7,
    this.fatigue = 0.3,
    this.completedToday = 0,
  });

  final double energy;
  final double fatigue;
  final int completedToday;

  SIState copyWith({double? energy, double? fatigue, int? completedToday}) {
    return SIState(
      energy: energy ?? this.energy,
      fatigue: fatigue ?? this.fatigue,
      completedToday: completedToday ?? this.completedToday,
    );
  }
}
