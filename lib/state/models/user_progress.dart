import 'package:fantastic_guacamole/domain/policies/progression_policy.dart';

class UserProgress {
  const UserProgress({
    required this.xp,
    required this.level,
    required this.streak,
    required this.longestStreak,
  });

  final int xp;
  final int level;
  final int streak;
  final int longestStreak;

  int get xpInLevel => xp - ProgressionPolicy.xpForLevel(level);
  int get xpToNext => ProgressionPolicy.xpToNextLevel(xp);
  double get levelProgress => ProgressionPolicy.levelProgressFraction(xp);

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
