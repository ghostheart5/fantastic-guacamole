import 'package:fantastic_guacamole/domain/policies/progression_policy.dart';

/// CHRONOSPARK-CLASS: SHIPPING | Feature: Progression
///
/// Cumulative XP; level always derived from ProgressionPolicy.
class ProgressionEntity {
  const ProgressionEntity({this.xp = 0, this.level = 1, this.streak = 0});

  /// Cumulative lifetime XP. Never reset on level-up — [ProgressionPolicy] is
  /// the single source of truth for turning this into a level.
  final int xp;
  final int level;
  final int streak;

  int get xpToNextLevel => ProgressionPolicy.xpToNextLevel(xp);

  ProgressionEntity copyWith({int? xp, int? level, int? streak}) {
    return ProgressionEntity(
      xp: xp ?? this.xp,
      level: level ?? this.level,
      streak: streak ?? this.streak,
    );
  }

  /// Canonical XP award: adds to cumulative XP and recomputes the level from
  /// [ProgressionPolicy]. This is the only path that may change [level] as a
  /// result of gameplay — see `AwardXp` for the persisting equivalent.
  ProgressionEntity awardXp(int amount) {
    if (amount < 0) {
      throw ArgumentError.value(amount, 'amount', 'XP award cannot be negative');
    }
    final int newXp = xp + amount;
    return copyWith(xp: newXp, level: ProgressionPolicy.levelFromXp(newXp));
  }

  @Deprecated(
    'Used a per-level XP reset curve that conflicted with ProgressionPolicy. '
    'Use awardXp, which keeps XP cumulative and derives level from the policy.',
  )
  ProgressionEntity addXp(int amount) => awardXp(amount);

  ProgressionEntity incrementStreak() => copyWith(streak: streak + 1);

  ProgressionEntity resetStreak() => copyWith(streak: 0);

  void validate() {
    if (xp < 0) throw StateError('XP cannot be negative');
    if (level < 1) throw StateError('Level must be at least 1');
  }
}
