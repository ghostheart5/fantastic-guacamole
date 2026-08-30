// CHRONOSPARK-CLASS: SHIPPING | Feature: Daily Rhythm occurrences
enum HabitOccurrenceOutcome { completed, skipped }

/// One durable, idempotent outcome for a Daily Rhythm cadence slot.
class HabitOccurrenceEntity {
  const HabitOccurrenceEntity({
    required this.habitId,
    required this.occurrenceKey,
    required this.operationId,
    required this.outcome,
    required this.recordedAt,
  });

  final String habitId;
  final String occurrenceKey;
  final String operationId;
  final HabitOccurrenceOutcome outcome;
  final DateTime recordedAt;

  String get id => '$habitId::$occurrenceKey';

  Map<String, dynamic> toJson() => <String, dynamic>{
    'habitId': habitId,
    'occurrenceKey': occurrenceKey,
    'operationId': operationId,
    'outcome': outcome.name,
    'recordedAt': recordedAt.toUtc().toIso8601String(),
  };

  factory HabitOccurrenceEntity.fromJson(Map<String, dynamic> json) {
    final String habitId = json['habitId']?.toString().trim() ?? '';
    final String occurrenceKey = json['occurrenceKey']?.toString().trim() ?? '';
    final String operationId = json['operationId']?.toString().trim() ?? '';
    final DateTime? recordedAt = DateTime.tryParse(
      json['recordedAt']?.toString() ?? '',
    );
    if (habitId.isEmpty ||
        occurrenceKey.isEmpty ||
        operationId.isEmpty ||
        recordedAt == null) {
      throw const FormatException(
        'Daily Rhythm occurrence requires complete identity and time.',
      );
    }
    final HabitOccurrenceOutcome outcome = HabitOccurrenceOutcome.values
        .firstWhere(
          (HabitOccurrenceOutcome value) =>
              value.name == json['outcome']?.toString(),
          orElse: () => throw const FormatException(
            'Daily Rhythm occurrence outcome is invalid.',
          ),
        );
    return HabitOccurrenceEntity(
      habitId: habitId,
      occurrenceKey: occurrenceKey,
      operationId: operationId,
      outcome: outcome,
      recordedAt: recordedAt.toUtc(),
    );
  }
}
