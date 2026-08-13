import 'package:fantastic_guacamole/domain/progression/progression_calculator.dart';

class UserProgress {
  const UserProgress({
    required this.xp,
    required this.level,
    required this.streak,
    required this.longestStreak,
    this.legacyLevelFloor = 1,
  });

  final int xp;
  final int level;
  final int streak;
  final int longestStreak;
  final int legacyLevelFloor;

  ProgressionCalculation get _calculation => const ProgressionCalculator()
      .calculate(xp: xp, legacyLevelFloor: legacyLevelFloor);
  int get canonicalLevel => _calculation.effectiveLevel;
  int get xpInLevel => _calculation.xpInPolicyLevel;
  int get xpToNext => _calculation.xpToNextLevel;
  double get levelProgress => _calculation.progressWithinLevel;

  String get levelTitle {
    if (level >= 8) return 'Deep Work Mode';
    if (level >= 4) return 'Building Momentum';
    return 'Getting Started';
  }

  String get streakMessage {
    if (streak >= 10) return 'Elite consistency achieved';
    if (streak >= 5) return 'Consistency is building momentum';
    if (streak >= 2) return 'Keep the chain going';
    return 'Start your streak today';
  }
}
