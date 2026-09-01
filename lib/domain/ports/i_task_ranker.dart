import 'package:fantastic_guacamole/domain/entities/learning_state.dart';
import 'package:fantastic_guacamole/domain/entities/ranked_task.dart';
import 'package:fantastic_guacamole/domain/entities/si_state_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/policies/task_ranking_policy.dart';

/// CHRONOSPARK-CLASS: SHIPPING | Feature: Task ranking
abstract interface class ITaskRanker {
  List<RankedTask> rank(
    List<TaskEntity> tasks, {
    required LearningState learning,
    required double energy,
    double fatigue = 0.0,
    double priorityScale = 1.0,
    double difficultyScale = 1.0,
    TaskRankingPolicy policy = const TaskRankingPolicy(),
    DateTime? now,
    SiStateEntity? siState,
  });

  TaskEntity? best(
    List<TaskEntity> tasks, {
    required LearningState learning,
    required double energy,
    double fatigue = 0.0,
    double priorityScale = 1.0,
    double difficultyScale = 1.0,
    TaskRankingPolicy policy = const TaskRankingPolicy(),
    DateTime? now,
    SiStateEntity? siState,
  });
}
