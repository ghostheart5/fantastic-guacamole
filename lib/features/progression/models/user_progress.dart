class UserProgress {
  const UserProgress({
    required this.xp,
    required this.level,
    required this.streak,
    required this.longestStreak,
    required this.xpPerLevel,
  });

  final int xp;
  final int level;
  final int streak;
  final int longestStreak;
  final int xpPerLevel;

  int get xpInLevel => xp % xpPerLevel;
  int get xpToNext => xpPerLevel - xpInLevel;
  double get levelProgress => (xpInLevel / xpPerLevel).clamp(0.0, 1.0);

  String get levelTitle {
    if (level >= 10) return 'Temporal Master';
    if (level >= 7) return 'Chronos Expert';
    if (level >= 5) return 'Focused Operative';
    if (level >= 3) return 'Building Momentum';
    return 'Developing Consistency';
  }

  String get streakMessage {
    if (streak >= 10) return 'Elite consistency achieved';
    if (streak >= 5) return 'Consistency is building momentum';
    if (streak >= 2) return 'Keep the chain going';
    return 'Start your streak today';
  }
}
