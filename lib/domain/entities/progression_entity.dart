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

  // Domain logic
  ProgressionEntity addXp(int amount) {
    int newXp = xp + amount;
    int newLevel = level;

    while (newXp >= newLevel * 50) {
      newXp -= newLevel * 50;
      newLevel++;
    }

    return copyWith(xp: newXp, level: newLevel);
  }

  ProgressionEntity incrementStreak() => copyWith(streak: streak + 1);

  ProgressionEntity resetStreak() => copyWith(streak: 0);

  void validate() {
    if (xp < 0) throw StateError('XP cannot be negative');
    if (level < 1) throw StateError('Level must be at least 1');
  }
}
