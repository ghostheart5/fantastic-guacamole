class ProfileModel {
  const ProfileModel({
    required this.name,
    required this.level,
    required this.xp,
    required this.streak,
    required this.longestStreak,
    required this.soundEnabled,
  });

  final String name;
  final int level;
  final int xp;
  final int streak;
  final int longestStreak;
  final bool soundEnabled;

  int get xpInLevel => xp % 50;
  int get xpToNext => 50 - xpInLevel;
}
