import 'package:fantastic_guacamole/domain/entities/decision_observation_entity.dart';

class LearningEntity {
  const LearningEntity({
    this.effortWeight = 1.0,
    this.priorityWeight = 1.0,
    this.completed = 0,
    this.skipped = 0,
    this.acceptedRecommendations = 0,
    this.rejectedRecommendations = 0,
    this.taskAffinity = const <String, double>{},
    this.observations = const <DecisionObservationEntity>[],
  });

  final double effortWeight;
  final double priorityWeight;
  final int completed;
  final int skipped;
  final int acceptedRecommendations;
  final int rejectedRecommendations;
  final Map<String, double> taskAffinity;
  final List<DecisionObservationEntity> observations;

  LearningEntity copyWith({
    double? effortWeight,
    double? priorityWeight,
    int? completed,
    int? skipped,
    int? acceptedRecommendations,
    int? rejectedRecommendations,
    Map<String, double>? taskAffinity,
    List<DecisionObservationEntity>? observations,
  }) {
    return LearningEntity(
      effortWeight: effortWeight ?? this.effortWeight,
      priorityWeight: priorityWeight ?? this.priorityWeight,
      completed: completed ?? this.completed,
      skipped: skipped ?? this.skipped,
      acceptedRecommendations:
          acceptedRecommendations ?? this.acceptedRecommendations,
      rejectedRecommendations:
          rejectedRecommendations ?? this.rejectedRecommendations,
      taskAffinity: taskAffinity ?? this.taskAffinity,
      observations: observations ?? this.observations,
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

  /// Attribution is only valid when the same task was actually shown as a
  /// recommendation. A generic task completion is not recommendation feedback.
  bool wasRecentlyRecommended(String taskId, {DateTime? at}) {
    final DateTime cutoff = (at ?? DateTime.now()).subtract(
      const Duration(days: 1),
    );
    return observations.any((DecisionObservationEntity observation) =>
        observation.type == DecisionObservationType.recommendationShown &&
        observation.taskId == taskId &&
        observation.timestamp.isAfter(cutoff));
  }

  LearningEntity recordRecommendationOutcome({
    required String taskId,
    required bool accepted,
    DateTime? timestamp,
  }) {
    final String id = taskId.trim();
    if (id.isEmpty) return this;
    final DateTime at = timestamp ?? DateTime.now();
    final DecisionObservationType observationType = accepted
        ? DecisionObservationType.recommendationAccepted
        : DecisionObservationType.recommendationRejected;
    if (_hasRecentObservation(
      type: observationType,
      taskId: id,
      source: 'recommendation_feedback',
      at: at,
    )) {
      return this;
    }
    final double current = taskAffinity[id] ?? 0.5;
    final double target = accepted ? 1.0 : 0.0;
    final Map<String, double> next = Map<String, double>.from(taskAffinity)
      ..[id] = (current * 0.7 + target * 0.3).clamp(0.0, 1.0).toDouble();
    return recordObservation(
      type: observationType,
      taskId: id,
      source: 'recommendation_feedback',
      timestamp: at,
    ).copyWith(
      acceptedRecommendations:
          accepted ? acceptedRecommendations + 1 : acceptedRecommendations,
      rejectedRecommendations:
          accepted ? rejectedRecommendations : rejectedRecommendations + 1,
      taskAffinity: Map<String, double>.unmodifiable(next),
    );
  }

  LearningEntity recordObservation({
    required DecisionObservationType type,
    String? taskId,
    required String source,
    DateTime? timestamp,
  }) {
    final DateTime at = timestamp ?? DateTime.now();
    if (_hasRecentObservation(
      type: type,
      taskId: taskId,
      source: source,
      at: at,
    )) {
      return this;
    }
    final String id = '${type.name}:${taskId ?? ''}:${at.microsecondsSinceEpoch}';
    final List<DecisionObservationEntity> next = <DecisionObservationEntity>[
      DecisionObservationEntity(
        id: id,
        type: type,
        timestamp: at,
        source: source,
        taskId: taskId,
      ),
      ...observations,
    ].take(200).toList(growable: false);
    return copyWith(observations: List<DecisionObservationEntity>.unmodifiable(next));
  }

  bool _hasRecentObservation({
    required DecisionObservationType type,
    required String? taskId,
    required String source,
    required DateTime at,
  }) {
    return observations.any((DecisionObservationEntity observation) =>
        observation.type == type &&
        observation.taskId == taskId &&
        observation.source == source &&
        at.difference(observation.timestamp).abs() < const Duration(seconds: 2));
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'effortWeight': effortWeight,
    'priorityWeight': priorityWeight,
    'completed': completed,
    'skipped': skipped,
    'acceptedRecommendations': acceptedRecommendations,
    'rejectedRecommendations': rejectedRecommendations,
    'taskAffinity': taskAffinity,
    'observations': observations.map((item) => item.toJson()).toList(),
  };

  factory LearningEntity.fromJson(Map<String, dynamic> json) {
    return LearningEntity(
      effortWeight: ((json['effortWeight'] as num?) ?? 1.0).toDouble(),
      priorityWeight: ((json['priorityWeight'] as num?) ?? 1.0).toDouble(),
      completed: (json['completed'] as num?)?.toInt() ?? 0,
      skipped: (json['skipped'] as num?)?.toInt() ?? 0,
      acceptedRecommendations:
          (json['acceptedRecommendations'] as num?)?.toInt() ?? 0,
      rejectedRecommendations:
          (json['rejectedRecommendations'] as num?)?.toInt() ?? 0,
      taskAffinity: ((json['taskAffinity'] as Map<Object?, Object?>?) ?? const <Object?, Object?>{})
          .map<String, double>((dynamic key, dynamic value) => MapEntry(
                key.toString(),
                ((value as num?) ?? 0.5)
                    .toDouble()
                    .clamp(0.0, 1.0)
                    .toDouble(),
              )),
      observations: ((json['observations'] as List?) ?? const <dynamic>[])
          .whereType<Map<Object?, Object?>>()
          .map((Map<Object?, Object?> item) => DecisionObservationEntity.fromJson(
                item.map<String, dynamic>(
                  (Object? key, Object? value) => MapEntry(key.toString(), value),
                ),
              ))
          .toList(growable: false),
    );
  }

  void validate() {
    if (effortWeight < 0.5 || effortWeight > 2 ||
        priorityWeight < 0.5 || priorityWeight > 2 ||
        completed < 0 || skipped < 0 ||
        acceptedRecommendations < 0 || rejectedRecommendations < 0) {
      throw StateError('Weights must be positive');
    }
    if (taskAffinity.entries.any((MapEntry<String, double> entry) =>
        entry.key.trim().isEmpty || entry.value < 0 || entry.value > 1)) {
      throw StateError('Task affinity values must be associated with valid task ids');
    }
    if (observations.any((DecisionObservationEntity observation) =>
        observation.id.trim().isEmpty || observation.source.trim().isEmpty)) {
      throw StateError('Learning observations require ids and sources');
    }
  }
}
