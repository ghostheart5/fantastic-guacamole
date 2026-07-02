class ProgressionPolicy {
  static int calculateXp({
    required int seconds,
    required int taskPriority,
    required double energy,
  }) {
    final int minutes = (seconds / 60).round();
    final int base = minutes.clamp(1, 60);
    final int priorityBonus = taskPriority.clamp(1, 5) * 4;
    final int energyBonus = (energy.clamp(0.0, 1.0) * 12).round();
    return base + priorityBonus + energyBonus;
  }

  static int levelFromXp(int xp) {
    return (xp ~/ 50) + 1;
  }

  static bool didLevelUp({required int previousLevel, required int xp}) {
    return levelFromXp(xp) > previousLevel;
  }
}
