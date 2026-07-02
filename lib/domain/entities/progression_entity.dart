class ProgressionEntity {
  const ProgressionEntity({this.xp = 0, this.level = 1, this.streak = 0});

  final int xp;
  final int level;
  final int streak;

  int get xpToNextLevel {
    final int remaining = (level * 50) - xp;
    return remaining > 0 ? remaining : 0;
  }

  ProgressionEntity copyWith({int? xp, int? level, int? streak}) {
    return ProgressionEntity(
      xp: xp ?? this.xp,
      level: level ?? this.level,
      streak: streak ?? this.streak,
    );
  }
}
