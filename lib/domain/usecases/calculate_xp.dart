import 'package:fantastic_guacamole/domain/policies/progression_policy.dart';

/// CHRONOSPARK-CLASS: EXPERIMENTAL | Feature: Progression
///
/// Exploratory priority/energy-weighted XP formula. Shipping awards are the
/// flat ProgressionPolicy.taskXp via AwardXp. Do not treat as shipping
/// behaviour.
/// Alternative weighted XP formula. Not the shipping award rule.
///
/// Task completion currently awards the flat [ProgressionPolicy.taskXp] via
/// `AwardXp`. This priority/energy-weighted variant is kept for a future
/// difficulty-aware progression pass; it is not wired into any completion path.
/// Inputs are clamped so it can never produce a negative or unbounded award if
/// it is adopted.
///
/// NOTE: [seconds] is accepted but not yet used — completion length is not part of
/// the formula. Kept in the signature so callers do not change when it is.
class CalculateXp {
  int call({
    required int seconds,
    required int taskPriority,
    required double energy,
  }) {
    final int priority = taskPriority.clamp(1, 5);
    final double clampedEnergy = energy.clamp(0.0, 1.0);
    final int base = ProgressionPolicy.taskXp * priority;
    final double energyBonus = clampedEnergy * 0.5 + 0.5;
    return (base * energyBonus).round();
  }
}
