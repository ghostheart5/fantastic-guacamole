import 'package:fantastic_guacamole/domain/policies/progression_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProgressionPolicy', () {
    test('static XP awards stay stable', () {
      expect(ProgressionPolicy.taskXp, 10);
      expect(ProgressionPolicy.sessionXp, 25);
      expect(ProgressionPolicy.streakDayXp, 15);
    });

    test('levelFromXp follows square-root thresholds', () {
      expect(ProgressionPolicy.levelFromXp(0), 1);
      expect(ProgressionPolicy.levelFromXp(99), 1);
      expect(ProgressionPolicy.levelFromXp(100), 2);
      expect(ProgressionPolicy.levelFromXp(399), 2);
      expect(ProgressionPolicy.levelFromXp(400), 3);
    });

    test('xpForLevel returns expected thresholds', () {
      expect(ProgressionPolicy.xpForLevel(1), 0);
      expect(ProgressionPolicy.xpForLevel(2), 100);
      expect(ProgressionPolicy.xpForLevel(3), 400);
      expect(ProgressionPolicy.xpForLevel(4), 900);
    });

    test('levelProgressFraction clamps in range and tracks current band', () {
      expect(ProgressionPolicy.levelProgressFraction(-10), 0.0);
      expect(ProgressionPolicy.levelProgressFraction(100), 0.0);
      expect(
        ProgressionPolicy.levelProgressFraction(150),
        closeTo(0.1666, 0.001),
      );
      expect(
        ProgressionPolicy.levelProgressFraction(10000),
        inInclusiveRange(0.0, 1.0),
      );
    });

    test('xpToNextLevel and didLevelUp report progression correctly', () {
      expect(ProgressionPolicy.xpToNextLevel(0), 100);
      expect(ProgressionPolicy.xpToNextLevel(100), 300);
      expect(ProgressionPolicy.didLevelUp(previousLevel: 1, xp: 99), isFalse);
      expect(ProgressionPolicy.didLevelUp(previousLevel: 1, xp: 100), isTrue);
    });

    test('levelProfile switches by level band', () {
      final low = ProgressionPolicy.levelProfile(1);
      final mid = ProgressionPolicy.levelProfile(4);
      final high = ProgressionPolicy.levelProfile(8);

      expect(low.tone, 'supportive');
      expect(low.minSessionMinutes, 5);
      expect(mid.tone, 'structured');
      expect(mid.maxDifficulty, 4);
      expect(high.tone, 'minimal');
      expect(high.maxSessionMinutes, 60);
    });
  });
}
