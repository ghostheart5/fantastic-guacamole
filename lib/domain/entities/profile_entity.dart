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
}
