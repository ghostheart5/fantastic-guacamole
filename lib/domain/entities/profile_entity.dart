import 'package:fantastic_guacamole/domain/policies/progression_policy.dart';

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
  int get xpToNextLevel => ProgressionPolicy.xpToNextLevel(xp);

  ProfileEntity addXp(int amount) {
    int newXp = xp + amount;
    final int newLevel = ProgressionPolicy.levelFromXp(newXp);
    final bool didLevelUp = newLevel > level;

    return copyWith(xp: newXp, level: newLevel, leveledUp: didLevelUp);
  }

  ProfileEntity incrementStreak() => copyWith(streak: streak + 1);

  ProfileEntity resetStreak() => copyWith(streak: 0);

  void validate() {
    if (xp < 0) throw StateError('XP cannot be negative');
    if (level < 1) throw StateError('Level must be at least 1');
  }
}
