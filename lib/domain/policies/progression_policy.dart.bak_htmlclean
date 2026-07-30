import 'dart:math' as math;

class LevelProfile {
  const LevelProfile({
    required this.minSessionMinutes,
    required this.maxSessionMinutes,
    required this.maxDifficulty,
    required this.tone,
  });

  final int minSessionMinutes;
  final int maxSessionMinutes;
  final int maxDifficulty;
  final String tone; // 'supportive' | 'structured' | 'minimal'
}

class ProgressionPolicy {
  // Flat XP awards — one number per action type, users can understand instantly.
  static const int taskXp = 10;
  static const int sessionXp = 25;
  static const int streakDayXp = 15;

  // Level = floor(sqrt(xp / 100)) + 1, minimum 1
  // XP needed: Level 2 = 100, Level 3 = 400, Level 4 = 900, Level 5 = 1600 …
  static int levelFromXp(int xp) {
    if (xp <= 0) return 1;
    return math.sqrt(xp / 100).floor() + 1;
  }

  // XP threshold to reach level N: (N-1)² × 100
  static int xpForLevel(int level) {
    final int n = level <= 1 ? 0 : level - 1;
    return n * n * 100;
  }

  // 0.0–1.0 progress within the current level band
  static double levelProgressFraction(int xp) {
    final int L = levelFromXp(xp);
    final int start = xpForLevel(L);
    final int end = xpForLevel(L + 1);
    if (end <= start) return 1.0;
    return ((xp - start) / (end - start)).clamp(0.0, 1.0);
  }

  static int xpToNextLevel(int xp) {
    return xpForLevel(levelFromXp(xp) + 1) - xp;
  }

  static bool didLevelUp({required int previousLevel, required int xp}) {
    return levelFromXp(xp) > previousLevel;
  }

  // Level band → session/difficulty/tone guidance
  static LevelProfile levelProfile(int level) {
    if (level >= 8) {
      return const LevelProfile(
        minSessionMinutes: 30,
        maxSessionMinutes: 60,
        maxDifficulty: 5,
        tone: 'minimal',
      );
    }
    if (level >= 4) {
      return const LevelProfile(
        minSessionMinutes: 15,
        maxSessionMinutes: 30,
        maxDifficulty: 4,
        tone: 'structured',
      );
    }
    return const LevelProfile(
      minSessionMinutes: 5,
      maxSessionMinutes: 10,
      maxDifficulty: 2,
      tone: 'supportive',
    );
  }
}
