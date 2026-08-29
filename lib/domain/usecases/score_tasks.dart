import 'package:fantastic_guacamole/domain/entities/learning_state.dart';
import 'package:fantastic_guacamole/domain/entities/ranked_task.dart';
import 'package:fantastic_guacamole/domain/entities/si_state_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/ports/i_task_ranker.dart';
import 'package:fantastic_guacamole/domain/policies/task_ranking_policy.dart';

/// CHRONOSPARK-CLASS: SHIPPING | Feature: Smart Planner / Trajectory Engine
///
/// Domain entry point for task scoring. The scoring formula stays in
/// [ITaskRanker] so this does not become a second, divergent implementation —
/// the codebase already carries one duplicate of the energy-fit maths in
/// `CalendarService`, and this deliberately does not add a third.
class ScoreTasks {
  const ScoreTasks(this._ranker);

  final ITaskRanker _ranker;

  /// Tasks ordered highest-score first.
  List<RankedTask> call(
    List<TaskEntity> tasks, {
    required LearningState learning,
    required double energy,
    double fatigue = 0.0,
    double priorityScale = 1.0,
    double difficultyScale = 1.0,
    TaskRankingPolicy policy = const TaskRankingPolicy(),
    DateTime? now,
    SiStateEntity? siState,
  }) {
    if (tasks.isEmpty) {
      return const <RankedTask>[];
    }
    return _ranker.rank(
      tasks,
      learning: learning,
      energy: energy,
      fatigue: fatigue,
      priorityScale: priorityScale,
      difficultyScale: difficultyScale,
      policy: policy,
      now: now,
      siState: siState,
    );
  }

  /// Highest-scoring task, or null when there is nothing to rank.
  TaskEntity? best(
    List<TaskEntity> tasks, {
    required LearningState learning,
    required double energy,
    double fatigue = 0.0,
    DateTime? now,
    SiStateEntity? siState,
  }) {
    return _ranker.best(
      tasks,
      learning: learning,
      energy: energy,
      fatigue: fatigue,
      now: now,
      siState: siState,
    );
  }
}
