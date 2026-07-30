import 'package:fantastic_guacamole/domain/policies/progression_policy.dart';

class CalculateXp {
  int call({
    required int seconds,
    required int taskPriority,
    required double energy,
  }) {
    final base = ProgressionPolicy.taskXp * taskPriority;
    final energyBonus = (energy * 0.5 + 0.5);
    return (base * energyBonus).round();
  }
}
