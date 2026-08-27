import 'package:fantastic_guacamole/domain/entities/decision_observation_entity.dart';
import 'package:fantastic_guacamole/engine/learning/learning_state.dart';

/// CHRONOSPARK-CLASS: PLANNED | Feature: Learning/adaptation
///
/// Adaptive weights consumed by LearningPolicy.
class LearningEntity extends LearningState {
  const LearningEntity({
    super.effortWeight,
    super.priorityWeight,
    super.completed,
    super.skipped,
    this.taskAffinity = const <String, double>{},
    this.observations = const <DecisionObservationEntity>[],
  });

  /// Per-task acceptance/completion affinity in the inclusive 0..1 range.
  /// It is keyed by stable task id, never by mutable task title.
  final Map<String, double> taskAffinity;

  /// Versioned outcome evidence used by planning confidence and recovery.
  final List<DecisionObservationEntity> observations;

  @override
  LearningEntity copyWith({
    double? effortWeight,
    double? priorityWeight,
    int? completed,
    int? skipped,
    Map<String, double>? taskAffinity,
    List<DecisionObservationEntity>? observations,
  }) {
    return LearningEntity(
      effortWeight: effortWeight ?? this.effortWeight,
      priorityWeight: priorityWeight ?? this.priorityWeight,
      completed: completed ?? this.completed,
      skipped: skipped ?? this.skipped,
      taskAffinity: Map<String, double>.unmodifiable(
        taskAffinity ?? this.taskAffinity,
      ),
      observations: List<DecisionObservationEntity>.unmodifiable(
        observations ?? this.observations,
      ),
    );
  }

  LearningEntity recordObservation(DecisionObservationEntity observation) {
    final List<DecisionObservationEntity> next = <DecisionObservationEntity>[
      ...observations,
      observation,
    ];
    final DateTime cutoff = observation.timestamp.subtract(
      const Duration(days: 90),
    );
    next.removeWhere(
      (DecisionObservationEntity item) => item.timestamp.isBefore(cutoff),
    );

    final String? taskId = observation.taskId;
    if (taskId == null || taskId.trim().isEmpty) {
      return copyWith(observations: next);
    }
    final double prior = taskAffinity[taskId] ?? .5;
    final bool positive =
        observation.type == DecisionObservationType.recommendationAccepted ||
        observation.type == DecisionObservationType.taskCompleted;
    final bool negative =
        observation.type == DecisionObservationType.recommendationRejected ||
        observation.type == DecisionObservationType.taskSkipped;
    final double updated = positive
        ? prior + ((1 - prior) * .2)
        : negative
        ? prior - (prior * .2)
        : prior;
    return copyWith(
      observations: next,
      taskAffinity: <String, double>{
        ...taskAffinity,
        taskId: updated.clamp(0.0, 1.0).toDouble(),
      },
    );
  }

  // Domain behavior
  double get score {
    final base = completed * effortWeight;
    final penalty = skipped * (effortWeight * 0.5);
    return base - penalty;
  }

  double get weightedScore {
    return (completed * effortWeight * priorityWeight) -
        (skipped * effortWeight * 0.5);
  }

  double get progressRatio {
    final total = completed + skipped;
    if (total == 0) return 0.0;
    return completed / total;
  }

  LearningEntity markCompleted() => copyWith(completed: completed + 1);

  LearningEntity markSkipped() => copyWith(skipped: skipped + 1);

  void validate() {
    if (effortWeight <= 0 || priorityWeight <= 0) {
      throw StateError('Weights must be positive');
    }
    if (taskAffinity.values.any((double value) => value < 0 || value > 1)) {
      throw StateError('Task affinity must be between zero and one');
    }
  }

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    'version': 2,
    'effortWeight': effortWeight,
    'priorityWeight': priorityWeight,
    'completed': completed,
    'skipped': skipped,
    'taskAffinity': taskAffinity,
    'observations': observations
        .map((DecisionObservationEntity item) => item.toJson())
        .toList(growable: false),
  };

  factory LearningEntity.fromJson(Map<String, dynamic> json) {
    final Object? affinityValue = json['taskAffinity'];
    final Map<String, double> affinity = affinityValue is Map
        ? affinityValue.map<String, double>(
            (dynamic key, dynamic value) => MapEntry(
              key.toString(),
              ((value as num?) ?? .5).toDouble().clamp(0.0, 1.0),
            ),
          )
        : const <String, double>{};
    final Object? observationValue = json['observations'];
    final List<DecisionObservationEntity> observations =
        observationValue is List
        ? observationValue
              .whereType<Map<dynamic, dynamic>>()
              .map(
                (Map<dynamic, dynamic> item) =>
                    DecisionObservationEntity.fromJson(
                      item.map<String, dynamic>(
                        (dynamic key, dynamic value) =>
                            MapEntry(key.toString(), value),
                      ),
                    ),
              )
              .toList(growable: false)
        : const <DecisionObservationEntity>[];
    return LearningEntity(
      effortWeight: ((json['effortWeight'] as num?) ?? 1).toDouble(),
      priorityWeight: ((json['priorityWeight'] as num?) ?? 1).toDouble(),
      completed: (json['completed'] as num?)?.toInt() ?? 0,
      skipped: (json['skipped'] as num?)?.toInt() ?? 0,
      taskAffinity: affinity,
      observations: observations,
    );
  }
}
