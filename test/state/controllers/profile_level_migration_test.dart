import 'package:fantastic_guacamole/domain/policies/progression_policy.dart';
import 'package:fantastic_guacamole/state/controllers/profile_controller.dart';
import 'package:flutter_test/flutter_test.dart';

/// The pre-migration curve that ProfileController used to ship.
int legacyLevel(int xp) => (xp ~/ 50) + 1;

void main() {
  group('ProfileState level grandfathering', () {
    test('a pre-migration record keeps its earned level', () {
      // A user at 2400 XP was level 49 under the old linear curve; the
      // canonical curve would put them at 5.
      const int xp = 2400;
      expect(legacyLevel(xp), 49);
      expect(ProgressionPolicy.levelFromXp(xp), 5);

      final ProfileState restored = ProfileState.fromJson(<String, dynamic>{
        'xp': xp,
        'level': legacyLevel(xp),
        'streak': 3,
        'longestStreak': 7,
      });

      expect(restored.level, 49, reason: 'displayed level must not drop');
      expect(restored.legacyLevelFloor, 49);
      expect(restored.xp, xp, reason: 'XP is untouched');
      expect(restored.isGrandfathered, isTrue);
    });

    test('the floor is captured once and then persisted explicitly', () {
      final ProfileState first = ProfileState.fromJson(<String, dynamic>{
        'xp': 1000,
        'level': legacyLevel(1000),
      });
      expect(first.legacyLevelFloor, 21);

      // Round-tripping must not re-derive or inflate the floor.
      final ProfileState second = ProfileState.fromJson(first.toJson());
      expect(second.legacyLevelFloor, 21);
      expect(second.level, 21);

      final ProfileState third = ProfileState.fromJson(second.toJson());
      expect(third.legacyLevelFloor, 21);
      expect(third.level, 21);
    });

    test('a new user is not grandfathered', () {
      final ProfileState fresh = ProfileState();

      expect(fresh.legacyLevelFloor, 1);
      expect(fresh.level, 1);
      expect(fresh.isGrandfathered, isFalse);
    });

    test('a user whose XP already exceeds the floor uses the policy', () {
      // Floor 3, but 1600 XP earns level 5 on the canonical curve.
      final ProfileState state = ProfileState.fromJson(<String, dynamic>{
        'xp': 1600,
        'legacyLevelFloor': 3,
      });

      expect(ProgressionPolicy.levelFromXp(1600), 5);
      expect(state.level, 5, reason: 'earned level overtakes the floor');
      expect(state.isGrandfathered, isFalse);
    });

    test('levelFor never returns less than the floor', () {
      for (final int xp in <int>[0, 1, 99, 100, 400, 900, 1600, 5000]) {
        for (final int floor in <int>[1, 5, 21, 49]) {
          final int level = ProfileState.levelFor(xp: xp, floor: floor);
          expect(level, greaterThanOrEqualTo(floor));
          expect(
            level,
            greaterThanOrEqualTo(ProgressionPolicy.levelFromXp(xp)),
          );
        }
      }
    });

    test('a record with no level and no floor defaults cleanly', () {
      final ProfileState state = ProfileState.fromJson(<String, dynamic>{
        'xp': 250,
      });

      // No stored level to grandfather, so the canonical curve applies.
      expect(state.legacyLevelFloor, 1);
      expect(state.level, ProgressionPolicy.levelFromXp(250));
    });

    test('legacyLevelFloor survives copyWith', () {
      final ProfileState state = ProfileState(
        xp: 2400,
        level: 49,
        legacyLevelFloor: 49,
      );

      expect(state.copyWith(xp: 2500).legacyLevelFloor, 49);
      expect(state.copyWith(streak: 9).legacyLevelFloor, 49);
    });

    test('a grandfathered user still advances once XP overtakes the floor', () {
      const int floor = 5;
      // Level 6 on the canonical curve begins at 2500 XP.
      expect(ProgressionPolicy.xpForLevel(6), 2500);

      expect(ProfileState.levelFor(xp: 2499, floor: floor), 5);
      expect(ProfileState.levelFor(xp: 2500, floor: floor), 6);
    });
  });
}
