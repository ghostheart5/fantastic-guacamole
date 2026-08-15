import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';

/// The only durable dispositions for a habit occurrence.
enum HabitOccurrenceStatus { completed, skipped }

/// Derived state for all required ordinals in one cadence period.
enum HabitPeriodStatus { open, completed, skipped, missed }

class HabitOccurrence {
  const HabitOccurrence({
    required this.habitId,
    required this.periodKey,
    required this.ordinal,
    required this.status,
    this.completedAt,
    this.skippedAt,
  });

  final String habitId;
  final String periodKey;
  final int ordinal;
  final HabitOccurrenceStatus status;
  final DateTime? completedAt;
  final DateTime? skippedAt;

  String get id => occurrenceId(habitId, periodKey, ordinal);

  static String occurrenceId(String habitId, String periodKey, int ordinal) =>
      '$habitId::$periodKey::$ordinal';

  Map<String, dynamic> toJson() => <String, dynamic>{
    'habitId': habitId,
    'periodKey': periodKey,
    'ordinal': ordinal,
    'status': status.name,
    'completedAt': completedAt?.toUtc().toIso8601String(),
    'skippedAt': skippedAt?.toUtc().toIso8601String(),
  };

  factory HabitOccurrence.fromJson(Map<String, dynamic> json) {
    final HabitOccurrenceStatus status = HabitOccurrenceStatus.values
        .firstWhere(
          (HabitOccurrenceStatus value) =>
              value.name == json['status']?.toString(),
        );
    return HabitOccurrence(
      habitId: json['habitId']?.toString() ?? '',
      periodKey: json['periodKey']?.toString() ?? '',
      ordinal: (json['ordinal'] as num?)?.toInt() ?? 1,
      status: status,
      completedAt: DateTime.tryParse(
        json['completedAt']?.toString() ?? '',
      )?.toLocal(),
      skippedAt: DateTime.tryParse(
        json['skippedAt']?.toString() ?? '',
      )?.toLocal(),
    );
  }
}

class HabitOccurrencePeriodKey {
  const HabitOccurrencePeriodKey._();

  static String forDate(HabitCadence cadence, DateTime value) {
    final DateTime local = value.toLocal();
    switch (cadence) {
      case HabitCadence.daily:
        return _date(local);
      case HabitCadence.weekly:
        final DateTime monday = local.subtract(
          Duration(days: local.weekday - DateTime.monday),
        );
        return 'W-${_date(monday)}';
      case HabitCadence.monthly:
        return '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}';
    }
  }

  static String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}

HabitPeriodStatus deriveHabitPeriodStatus({
  required int targetCount,
  required Iterable<HabitOccurrence> occurrences,
  required bool isCurrentPeriod,
}) {
  final Map<int, HabitOccurrence> byOrdinal = <int, HabitOccurrence>{
    for (final HabitOccurrence occurrence in occurrences)
      occurrence.ordinal: occurrence,
  };
  final int required = targetCount.clamp(1, 365);
  final List<HabitOccurrence?> requiredOccurrences =
      List<HabitOccurrence?>.generate(
        required,
        (int index) => byOrdinal[index + 1],
      );
  if (requiredOccurrences.every(
    (HabitOccurrence? item) => item?.status == HabitOccurrenceStatus.completed,
  )) {
    return HabitPeriodStatus.completed;
  }
  if (requiredOccurrences.every((HabitOccurrence? item) => item != null) &&
      requiredOccurrences.any(
        (HabitOccurrence? item) =>
            item?.status == HabitOccurrenceStatus.skipped,
      )) {
    return HabitPeriodStatus.skipped;
  }
  return isCurrentPeriod ? HabitPeriodStatus.open : HabitPeriodStatus.missed;
}

class HabitStreak {
  const HabitStreak({required this.currentStreak, required this.longestStreak});

  final int currentStreak;
  final int longestStreak;
}

HabitStreak deriveHabitStreak(Iterable<HabitPeriodStatus> orderedStatuses) {
  int current = 0;
  int longest = 0;
  for (final HabitPeriodStatus status in orderedStatuses) {
    switch (status) {
      case HabitPeriodStatus.completed:
        current += 1;
        if (current > longest) longest = current;
      case HabitPeriodStatus.skipped:
      case HabitPeriodStatus.open:
        break;
      case HabitPeriodStatus.missed:
        current = 0;
    }
  }
  return HabitStreak(currentStreak: current, longestStreak: longest);
}
