// CHRONOSPARK-CLASS: SHIPPING | Feature: Emotional safety routing

import 'package:fantastic_guacamole/domain/policies/emotional_safety_policy.dart';

/// Compatibility boundary for callers that need only the immediate-safety
/// decision. New surfaces should consume [EmotionalSafetyPolicy.assess] so
/// non-crisis distress cannot fall into ordinary productivity guidance.
abstract final class CrisisDetectionPolicy {
  static bool detects(String input) =>
      EmotionalSafetyPolicy.assess(input).requiresImmediateSafety;
}
