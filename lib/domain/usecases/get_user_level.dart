import 'package:fantastic_guacamole/domain/policies/progression_policy.dart';

/// CHRONOSPARK-CLASS: PLANNED | Feature: Progression
///
/// Policy-backed level read model. Registered as getUserLevelUseCaseProvider;
/// ready for the progression UI.
class GetUserLevel {
  int level(int xp) => ProgressionPolicy.levelFromXp(xp);
  double progress(int xp) => ProgressionPolicy.levelProgressFraction(xp);
  int xpToNext(int xp) => ProgressionPolicy.xpToNextLevel(xp);
}
