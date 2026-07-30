import 'package:fantastic_guacamole/domain/policies/progression_policy.dart';

class GetUserLevel {
  int level(int xp) => ProgressionPolicy.levelFromXp(xp);
  double progress(int xp) => ProgressionPolicy.levelProgressFraction(xp);
  int xpToNext(int xp) => ProgressionPolicy.xpToNextLevel(xp);
}
