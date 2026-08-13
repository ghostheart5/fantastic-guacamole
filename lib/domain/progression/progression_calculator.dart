import 'package:fantastic_guacamole/domain/policies/progression_policy.dart';

/// Pure projection of persisted XP and compatibility-floor state.
class ProgressionCalculation {
  const ProgressionCalculation({
    required this.xp,
    required this.policyLevel,
    required this.effectiveLevel,
    required this.xpInPolicyLevel,
    required this.xpToNextLevel,
    required this.progressWithinLevel,
  });

  final int xp;
  final int policyLevel;
  final int effectiveLevel;
  final int xpInPolicyLevel;
  final int xpToNextLevel;
  final double progressWithinLevel;
}

/// Canonical, deterministic calculation boundary for progression metrics.
///
/// [ProgressionPolicy] remains the authority for thresholds and award rules.
/// This calculator applies those rules consistently and preserves the explicit
/// legacy level floor required by historical Profile records.
class ProgressionCalculator {
  const ProgressionCalculator();

  int policyLevel(int xp) => ProgressionPolicy.levelFromXp(_safeXp(xp));

  int effectiveLevel({required int xp, int legacyLevelFloor = 1}) {
    final int floor = legacyLevelFloor < 1 ? 1 : legacyLevelFloor;
    final int policy = policyLevel(xp);
    return policy > floor ? policy : floor;
  }

  int xpToNextLevel(int xp) => ProgressionPolicy.xpToNextLevel(_safeXp(xp));

  double progressWithinLevel(int xp) =>
      ProgressionPolicy.levelProgressFraction(_safeXp(xp));

  ProgressionCalculation calculate({
    required int xp,
    int legacyLevelFloor = 1,
  }) {
    final int safeXp = _safeXp(xp);
    return ProgressionCalculation(
      xp: safeXp,
      policyLevel: policyLevel(safeXp),
      effectiveLevel: effectiveLevel(
        xp: safeXp,
        legacyLevelFloor: legacyLevelFloor,
      ),
      xpInPolicyLevel: safeXp - ProgressionPolicy.xpForLevel(policyLevel(safeXp)),
      xpToNextLevel: xpToNextLevel(safeXp),
      progressWithinLevel: progressWithinLevel(safeXp),
    );
  }

  int _safeXp(int xp) => xp < 0 ? 0 : xp;
}
