import 'package:fantastic_guacamole/domain/progression/progression_calculator.dart';

class ProfileEntity {
  const ProfileEntity({
    this.xp = 0,
    this.level = 1,
    this.legacyLevelFloor = 1,
    this.streak = 0,
    this.longestStreak = 0,
    this.name = 'Operative',
    this.lastActiveDate,
    this.profileReady = false,
  });

  final int xp;
  final int level;
  final int legacyLevelFloor;
  final int streak;
  final int longestStreak;
  final String name;
  final DateTime? lastActiveDate;
  final bool profileReady;

  ProfileEntity copyWith({
    int? xp,
    int? level,
    int? legacyLevelFloor,
    int? streak,
    int? longestStreak,
    String? name,
    DateTime? lastActiveDate,
    bool? profileReady,
    bool clearLastActiveDate = false,
  }) {
    return ProfileEntity(
      xp: xp ?? this.xp,
      level: level ?? this.level,
      legacyLevelFloor: legacyLevelFloor ?? this.legacyLevelFloor,
      streak: streak ?? this.streak,
      longestStreak: longestStreak ?? this.longestStreak,
      name: name ?? this.name,
      lastActiveDate: clearLastActiveDate
          ? null
          : (lastActiveDate ?? this.lastActiveDate),
      profileReady: profileReady ?? this.profileReady,
    );
  }

  // Domain logic
  int get xpToNextLevel => const ProgressionCalculator().xpToNextLevel(xp);

  ProfileEntity addXp(int amount) {
    final ProgressionCalculation progression = const ProgressionCalculator()
        .calculate(xp: xp + amount);
    return copyWith(
      xp: progression.xp,
      level: progression.effectiveLevel,
      legacyLevelFloor: progression.effectiveLevel > legacyLevelFloor
          ? progression.effectiveLevel
          : legacyLevelFloor,
    );
  }

  ProfileEntity incrementStreak() => copyWith(
    streak: streak + 1,
    longestStreak: streak + 1 > longestStreak ? streak + 1 : longestStreak,
  );

  ProfileEntity resetStreak() => copyWith(streak: 0);

  void validate() {
    if (xp < 0) throw StateError('XP cannot be negative');
    if (level < 1) throw StateError('Level must be at least 1');
  }
}
