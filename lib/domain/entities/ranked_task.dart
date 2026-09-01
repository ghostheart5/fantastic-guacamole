import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/predictive/predictive_planning_contract.dart';

/// CHRONOSPARK-CLASS: SHIPPING | Feature: Task ranking
class RankedTask {
  const RankedTask({
    required this.task,
    required this.score,
    required this.breakdown,
  });

  final TaskEntity task;
  final double score;
  final TaskScoreBreakdown breakdown;
}
