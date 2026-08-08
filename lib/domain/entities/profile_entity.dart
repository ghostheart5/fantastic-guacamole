import 'package:fantastic_guacamole/domain/policies/progression_policy.dart';

/// CHRONOSPARK-CLASS: PLANNED | Feature: Progression
///
/// Domain profile model; ProfileController is the shipping profile state.
class ProfileEntity {
  const ProfileEntity({
    this.xp = 0,
    this.level = 1,
    this.streak = 0,
    this.leveledUp = false,
  });

  /// Cumulative lifetime XP. [ProgressionPolicy] is the single source of truth
  /// for turning this into a level.
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

  /// Canonical XP award. Mirrors [ProgressionEntity.awardXp] and additionally
  /// reports whether the award crossed a level threshold.
  ProfileEntity awardXp(int amount) {
    if (amount < 0) {
      throw ArgumentError.value(
        amount,
        'amount',
        'XP award cannot be negative',
      );
    }
    final int newXp = xp + amount;
    final int newLevel = ProgressionPolicy.levelFromXp(newXp);
    return copyWith(xp: newXp, level: newLevel, leveledUp: newLevel > level);
  }

  @Deprecated(
    'Used a per-level XP reset curve that conflicted with ProgressionPolicy. '
    'Use awardXp, which keeps XP cumulative and derives level from the policy.',
  )
  ProfileEntity addXp(int amount) => awardXp(amount);

  ProfileEntity incrementStreak() => copyWith(streak: streak + 1);

  ProfileEntity resetStreak() => copyWith(streak: 0);

  void validate() {
    if (xp < 0) throw StateError('XP cannot be negative');
    if (level < 1) throw StateError('Level must be at least 1');
  }
}
