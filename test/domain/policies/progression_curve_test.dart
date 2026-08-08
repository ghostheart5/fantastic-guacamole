import 'package:fantastic_guacamole/domain/entities/profile_entity.dart';
import 'package:fantastic_guacamole/domain/policies/progression_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProgressionPolicy is the canonical level curve', () {
    test('levelFromXp matches the documented thresholds', () {
      expect(ProgressionPolicy.levelFromXp(0), 1);
      expect(ProgressionPolicy.levelFromXp(-50), 1);
      expect(ProgressionPolicy.levelFromXp(99), 1);
      expect(ProgressionPolicy.levelFromXp(100), 2);
      expect(ProgressionPolicy.levelFromXp(399), 2);
      expect(ProgressionPolicy.levelFromXp(400), 3);
      expect(ProgressionPolicy.levelFromXp(900), 4);
      expect(ProgressionPolicy.levelFromXp(1600), 5);
    });

    test('xpForLevel is the inverse of levelFromXp at each boundary', () {
      for (int level = 1; level <= 10; level++) {
        final int threshold = ProgressionPolicy.xpForLevel(level);
        expect(
          ProgressionPolicy.levelFromXp(threshold),
          level,
          reason: 'xpForLevel($level) = $threshold should map back to $level',
        );
      }
    });

    test('xpToNextLevel reports the remaining XP to the next threshold', () {
      expect(ProgressionPolicy.xpToNextLevel(0), 100);
      expect(ProgressionPolicy.xpToNextLevel(100), 300);
      expect(ProgressionPolicy.xpToNextLevel(400), 500);
    });

    test('levelProgressFraction stays within 0..1', () {
      expect(ProgressionPolicy.levelProgressFraction(0), 0.0);
      expect(ProgressionPolicy.levelProgressFraction(50), closeTo(0.5, 1e-9));
      expect(ProgressionPolicy.levelProgressFraction(100), 0.0);
      for (final int xp in <int>[0, 1, 99, 100, 401, 1599, 5000]) {
        final double fraction = ProgressionPolicy.levelProgressFraction(xp);
        expect(fraction, inInclusiveRange(0.0, 1.0));
      }
    });

    test('didLevelUp agrees with levelFromXp', () {
      expect(
        ProgressionPolicy.didLevelUp(previousLevel: 1, xp: 99),
        isFalse,
      );
      expect(ProgressionPolicy.didLevelUp(previousLevel: 1, xp: 100), isTrue);
    });
  });

  group('ProfileEntity uses the same curve as ProgressionPolicy', () {
    test('awardXp derives level from the policy and flags level-up', () {
      const ProfileEntity profile = ProfileEntity(xp: 90, level: 1);

      final ProfileEntity updated = profile.awardXp(10);

      expect(updated.xp, 100);
      expect(updated.level, 2);
      expect(updated.leveledUp, isTrue);
    });

    test('awardXp does not flag a level-up when no threshold is crossed', () {
      const ProfileEntity profile = ProfileEntity(xp: 10, level: 1);

      final ProfileEntity updated = profile.awardXp(10);

      expect(updated.level, 1);
      expect(updated.leveledUp, isFalse);
    });

    test('xpToNextLevel matches the policy', () {
      const ProfileEntity profile = ProfileEntity(xp: 100, level: 2);

      expect(profile.xpToNextLevel, ProgressionPolicy.xpToNextLevel(100));
    });

    test('rejects negative awards', () {
      expect(() => const ProfileEntity().awardXp(-1), throwsArgumentError);
    });
  });
}
