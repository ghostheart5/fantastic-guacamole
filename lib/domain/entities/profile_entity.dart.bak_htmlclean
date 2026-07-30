class ProfileEntity {
  const ProfileEntity({
    this.xp = 0,
    this.level = 1,
    this.streak = 0,
    this.leveledUp = false,
  });

  final int xp;
  final int level;
  final int streak;
  final bool leveledUp;

  ProfileEntity copyWith({int? xp, int? level, int? streak, bool? leveledUp}) {
    return ProfileEntity(
      xp: xp ?? this.xp,
      level: level ?? this.level,
      streak: streak ?? this.streak,
      leveledUp: leveledUp ?? this.leveledUp,
    );
  }

  // Domain logic
  int get xpToNextLevel => level * 100;

  ProfileEntity addXp(int amount) {
    int newXp = xp + amount;
    int newLevel = level;
    bool didLevelUp = false;

    while (newXp >= newLevel * 100) {
      newXp -= newLevel * 100;
      newLevel++;
      didLevelUp = true;
    }

    return copyWith(xp: newXp, level: newLevel, leveledUp: didLevelUp);
  }

  ProfileEntity incrementStreak() => copyWith(streak: streak + 1);

  ProfileEntity resetStreak() => copyWith(streak: 0);

  void validate() {
    if (xp < 0) throw StateError('XP cannot be negative');
    if (level < 1) throw StateError('Level must be at least 1');
  }
}
