import 'package:fantastic_guacamole/domain/entities/si_state_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/engine/learning/learning_state.dart';

class RankedTask {
  const RankedTask({required this.task, required this.score});

  final TaskEntity task;
  final double score;
}

class TaskRanker {
  const TaskRanker();

  /// Returns tasks sorted highest-score first.
  /// When [siState.avoidOverwhelm] is true, ranks by ease instead of priority.
  List<RankedTask> rank(
    List<TaskEntity> tasks, {
    required LearningState learning,
    required double energy,
    double fatigue = 0.0,
    DateTime? now,
    SiStateEntity? siState,
  }) {
    if (siState?.avoidOverwhelm == true) {
      return _rankByEase(tasks);
    }
    final DateTime ref = now ?? DateTime.now();
    return tasks
        .map(
          (t) => RankedTask(
            task: t,
            score: _score(t, learning, energy, fatigue, ref),
          ),
        )
        .toList()
      ..sort((a, b) => b.score.compareTo(a.score));
  }

  /// Top-ranked task, or null if list is empty.
  TaskEntity? best(
    List<TaskEntity> tasks, {
    required LearningState learning,
    required double energy,
    double fatigue = 0.0,
    DateTime? now,
    SiStateEntity? siState,
  }) {
    if (tasks.isEmpty) return null;
    return rank(
      tasks,
      learning: learning,
      energy: energy,
      fatigue: fatigue,
      now: now,
      siState: siState,
    ).first.task;
  }

  /// Ease-first ranking: sort by difficulty ascending, then energy match.
  List<RankedTask> _rankByEase(List<TaskEntity> tasks) {
    return tasks
        .map((t) => RankedTask(task: t, score: (5 - t.difficulty).toDouble()))
        .toList()
      ..sort((a, b) => b.score.compareTo(a.score));
  }

  double _score(
    TaskEntity task,
    LearningState learning,
    double energy,
    double fatigue,
    DateTime now,
  ) {
    final double energyNeed = task.energyRequired / 5.0;
    final double energyMatch = (1.0 - (energy - energyNeed).abs()).clamp(
      0.0,
      1.0,
    );

    double score = task.priority * learning.priorityWeight * 10.0;
    score += energyMatch * 12.0;
    score += (1.0 - fatigue) * 6.0;
    score -= task.difficulty * learning.effortWeight * fatigue * 4.0;

    if (energy >= energyNeed) score += 4.0;
    if (fatigue > 0.7 && task.difficulty <= 2) score += 3.0;

    final DateTime? dueDate = task.dueDate;
    if (dueDate != null) {
      final int hours = dueDate.difference(now).inHours;
      if (hours < 0) {
        score += 15.0;
      } else if (hours < 24) {
        score += 10.0;
      } else if (hours < 72) {
        score += 4.0;
      }
    }

    return score;
  }
}
