import 'package:fantastic_guacamole/domain/progression/progression_calculator.dart';

class ProgressionEntity {
  const ProgressionEntity({this.xp = 0, this.level = 1, this.streak = 0});

  final int xp;
  final int level;
  final int streak;

  int get xpToNextLevel => const ProgressionCalculator().xpToNextLevel(xp);

  ProgressionEntity copyWith({int? xp, int? level, int? streak}) {
    return ProgressionEntity(
      xp: xp ?? this.xp,
      level: level ?? this.level,
      streak: streak ?? this.streak,
    );
  }

  // Domain logic
  ProgressionEntity addXp(int amount) {
    final ProgressionCalculation progression = const ProgressionCalculator()
        .calculate(xp: xp + amount);

    return copyWith(xp: progression.xp, level: progression.effectiveLevel);
  }

  ProgressionEntity incrementStreak() => copyWith(streak: streak + 1);

  ProgressionEntity resetStreak() => copyWith(streak: 0);

  void validate() {
    if (xp < 0) throw StateError('XP cannot be negative');
    if (level < 1) throw StateError('Level must be at least 1');
  }
}
