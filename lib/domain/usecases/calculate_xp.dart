import 'package:fantastic_guacamole/domain/policies/progression_policy.dart';

class CalculateXp {
  int call({
    required int seconds,
    required int taskPriority,
    required double energy,
  }) {
    return ProgressionPolicy.calculateXp(
      seconds: seconds,
      taskPriority: taskPriority,
      energy: energy,
    );
  }
}
