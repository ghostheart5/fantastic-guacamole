import 'package:fantastic_guacamole/domain/entities/si_state_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/entities/learning_entity.dart';
import 'package:fantastic_guacamole/domain/predictive/predictive_planning_contract.dart';
import 'package:fantastic_guacamole/engine/learning/learning_state.dart';

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

class TaskRanker {
  const TaskRanker();

  /// Returns tasks sorted highest-score first.
  /// When [siState.avoidOverwhelm] is true, ranks by ease instead of priority.
  List<RankedTask> rank(
    List<TaskEntity> tasks, {
    required LearningState learning,
    required double energy,
    double fatigue = 0.0,
    double priorityScale = 1.0,
    double difficultyScale = 1.0,
    DateTime? now,
    SiStateEntity? siState,
  }) {
    final DateTime ref = now ?? DateTime.now();
    if (siState?.avoidOverwhelm == true) {
      return _rankByEase(tasks, ref);
    }
    return tasks.map((TaskEntity task) {
      final TaskScoreBreakdown breakdown = _breakdown(
        task,
        learning,
        energy,
        fatigue,
        priorityScale,
        difficultyScale,
        ref,
      );
      return RankedTask(
        task: task,
        score: breakdown.total,
        breakdown: breakdown,
      );
    }).toList()..sort((a, b) => b.score.compareTo(a.score));
  }

  /// Top-ranked task, or null if list is empty.
  TaskEntity? best(
    List<TaskEntity> tasks, {
    required LearningState learning,
    required double energy,
    double fatigue = 0.0,
    double priorityScale = 1.0,
    double difficultyScale = 1.0,
    DateTime? now,
    SiStateEntity? siState,
  }) {
    if (tasks.isEmpty) return null;
    return rank(
      tasks,
      learning: learning,
      energy: energy,
      fatigue: fatigue,
      priorityScale: priorityScale,
      difficultyScale: difficultyScale,
      now: now,
      siState: siState,
    ).first.task;
  }

  /// Ease-first ranking: sort by difficulty ascending, then energy match.
  List<RankedTask> _rankByEase(List<TaskEntity> tasks, DateTime now) {
    return tasks.map((TaskEntity task) {
      final double score = (5 - task.difficulty).toDouble();
      return RankedTask(
        task: task,
        score: score,
        breakdown: TaskScoreBreakdown(
          taskId: task.id,
          priority: 0,
          deadlinePressure: _deadlinePressure(task, now),
          energyFit: 0,
          fatigueAdjustment: 0,
          difficultyAdjustment: score,
          learningAffinity: 0,
          total: score,
          reasons: const <String>[
            'Ease-first ranking is active to reduce overwhelm.',
          ],
        ),
      );
    }).toList()..sort((a, b) => b.score.compareTo(a.score));
  }

  TaskScoreBreakdown _breakdown(
    TaskEntity task,
    LearningState learning,
    double energy,
    double fatigue,
    double priorityScale,
    double difficultyScale,
    DateTime now,
  ) {
    final double energyNeed = task.energyRequired / 5.0;
    final double energyMatch = (1.0 - (energy - energyNeed).abs()).clamp(
      0.0,
      1.0,
    );

    final double priorityContribution =
        task.priority * learning.priorityWeight * priorityScale * 10.0;
    final double energyContribution = energyMatch * 12.0;
    final double fatigueContribution = (1.0 - fatigue) * 6.0;
    final double difficultyAdjustment =
        -(task.difficulty *
            learning.effortWeight *
            difficultyScale *
            fatigue *
            4.0);
    final double affinity = learning is LearningEntity
        ? learning.taskAffinity[task.id] ?? .5
        : .5;
    final double affinityContribution = (affinity - .5) * 8;
    double score =
        priorityContribution +
        energyContribution +
        fatigueContribution +
        difficultyAdjustment +
        affinityContribution;

    if (energy >= energyNeed) score += 4.0;
    if (fatigue > 0.7 && task.difficulty <= 2) score += 3.0;

    final DeadlinePressureAssessment deadline = _deadlinePressure(task, now);
    score += deadline.score;
    return TaskScoreBreakdown(
      taskId: task.id,
      priority: priorityContribution,
      deadlinePressure: deadline,
      energyFit: energyContribution,
      fatigueAdjustment: fatigueContribution,
      difficultyAdjustment: difficultyAdjustment,
      learningAffinity: affinityContribution,
      total: score,
      reasons: <String>[
        'Priority contributed ${priorityContribution.toStringAsFixed(1)} points.',
        deadline.explanation,
        'Energy fit contributed ${energyContribution.toStringAsFixed(1)} points.',
        if (learning is LearningEntity &&
            learning.taskAffinity.containsKey(task.id))
          'Observed task affinity adjusted the score by ${affinityContribution.toStringAsFixed(1)} points.',
      ],
    );
  }

  DeadlinePressureAssessment _deadlinePressure(TaskEntity task, DateTime now) {
    final DateTime? due = task.dueDate;
    if (due == null) {
      return DeadlinePressureAssessment(
        taskId: task.id,
        band: DeadlinePressureBand.none,
        score: 0,
        slack: null,
        explanation: 'No deadline is recorded for this task.',
        origin: PredictiveEvidenceOrigin.unavailable,
      );
    }
    final Duration slack = due.difference(now) - task.estimateOrDefault;
    final DeadlinePressureBand band;
    final double score;
    if (due.isBefore(now)) {
      band = DeadlinePressureBand.overdue;
      score = 15;
    } else if (slack <= Duration.zero) {
      band = DeadlinePressureBand.critical;
      score = 12;
    } else if (slack <= const Duration(hours: 24)) {
      band = DeadlinePressureBand.elevated;
      score = 10;
    } else if (slack <= const Duration(hours: 72)) {
      band = DeadlinePressureBand.watch;
      score = 4;
    } else {
      band = DeadlinePressureBand.none;
      score = 0;
    }
    return DeadlinePressureAssessment(
      taskId: task.id,
      band: band,
      score: score,
      slack: slack,
      explanation: switch (band) {
        DeadlinePressureBand.overdue => 'The recorded deadline has passed.',
        DeadlinePressureBand.critical =>
          'Estimated work no longer fits inside the remaining deadline slack.',
        DeadlinePressureBand.elevated =>
          'Less than one day of deadline slack remains.',
        DeadlinePressureBand.watch =>
          'Deadline slack is below three days and should be monitored.',
        DeadlinePressureBand.none => 'Deadline slack is currently sufficient.',
      },
      origin: PredictiveEvidenceOrigin.observed,
    );
  }
}
