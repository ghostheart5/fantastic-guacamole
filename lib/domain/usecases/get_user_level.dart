import 'package:fantastic_guacamole/domain/progression/progression_calculator.dart';

class GetUserLevel {
  static const _calculator = ProgressionCalculator();

  int level(int xp) => _calculator.policyLevel(xp);
  double progress(int xp) => _calculator.progressWithinLevel(xp);
  int xpToNext(int xp) => _calculator.xpToNextLevel(xp);
}
