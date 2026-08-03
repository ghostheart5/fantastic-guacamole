import 'package:fantastic_guacamole/domain/policies/progression_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProgressionPolicy boundaries', () {
    test('level thresholds and next-level deltas are coherent', () {
      expect(ProgressionPolicy.levelFromXp(99), 1);
      expect(ProgressionPolicy.levelFromXp(100), 2);
      expect(ProgressionPolicy.levelFromXp(399), 2);
      expect(ProgressionPolicy.levelFromXp(400), 3);

      expect(ProgressionPolicy.xpToNextLevel(0), 100);
      expect(ProgressionPolicy.xpToNextLevel(100), 300);
      expect(ProgressionPolicy.xpToNextLevel(399), 1);
    });

    test('level progress fraction is clamped and monotonic inside a band', () {
      final double atStart = ProgressionPolicy.levelProgressFraction(100);
      final double middle = ProgressionPolicy.levelProgressFraction(250);
      final double nearEnd = ProgressionPolicy.levelProgressFraction(399);

      expect(atStart, 0.0);
      expect(middle, greaterThan(atStart));
      expect(nearEnd, lessThanOrEqualTo(1.0));
      expect(nearEnd, greaterThan(middle));
    });

    test('level profiles switch guidance by band', () {
      final LevelProfile novice = ProgressionPolicy.levelProfile(1);
      final LevelProfile mid = ProgressionPolicy.levelProfile(4);
      final LevelProfile advanced = ProgressionPolicy.levelProfile(8);

      expect(novice.tone, 'supportive');
      expect(mid.tone, 'structured');
      expect(advanced.tone, 'minimal');
      expect(advanced.maxDifficulty, greaterThanOrEqualTo(mid.maxDifficulty));
    });
  });
}

