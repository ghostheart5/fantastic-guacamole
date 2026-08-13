import 'package:fantastic_guacamole/domain/policies/progression_policy.dart';
import 'package:fantastic_guacamole/domain/progression/progression_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const ProgressionCalculator calculator = ProgressionCalculator();

  group('ProgressionCalculator', () {
    test('uses the policy as its threshold authority', () {
      for (final int xp in <int>[0, 49, 50, 99, 100, 999]) {
        expect(calculator.calculate(xp: xp).policyLevel,
            ProgressionPolicy.levelFromXp(xp));
      }
    });

    test('normalizes negative XP', () {
      final ProgressionCalculation result = calculator.calculate(xp: -10);
      expect(result.xp, 0);
      expect(result.effectiveLevel, 1);
    });

    test('keeps an explicit historical level floor', () {
      final ProgressionCalculation result =
          calculator.calculate(xp: 0, legacyLevelFloor: 4);
      expect(result.policyLevel, 1);
      expect(result.effectiveLevel, 4);
    });

    test('allows policy progression beyond a historical floor', () {
      final ProgressionCalculation result =
          calculator.calculate(xp: 250, legacyLevelFloor: 2);
      expect(result.effectiveLevel, result.policyLevel);
    });

    test('owns the current policy-band metrics', () {
      final ProgressionCalculation result = calculator.calculate(xp: 75);
      expect(
        result.xpInPolicyLevel,
        75 - ProgressionPolicy.xpForLevel(result.policyLevel),
      );
      expect(result.xpToNextLevel, ProgressionPolicy.xpToNextLevel(75));
      expect(result.progressWithinLevel,
          ProgressionPolicy.levelProgressFraction(75));
    });
  });

}
