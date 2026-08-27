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
    if (streak == 0 && longestStreak > 0) {
      return 'Your history remains. Choose a gentle restart.';
    }
    if (streak >= 10) return 'A sustained rhythm is taking shape';
    if (streak >= 5) return 'Consistency is building momentum';
    if (streak >= 2) return 'Your current rhythm is building';
    return 'Begin with one manageable action';
  }
}
