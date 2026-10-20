import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';

/// Calendar projection of registered cadence metadata, not delivery precision.
DateTime nextRegisteredAutomationTime({
  required DateTime now,
  required int hour,
  required int minute,
  HabitCadence? cadence,
  DateTime? firstScheduledLocal,
}) {
  final first = firstScheduledLocal?.toLocal();
  if ((cadence == HabitCadence.weekly || cadence == HabitCadence.monthly) &&
      first == null) {
    throw StateError('Registered cadence has no first eligible date.');
  }
  final lower = first != null && first.isAfter(now) ? first : now;
  var candidate = DateTime(lower.year, lower.month, lower.day, hour, minute);
  for (var count = 0; count < 370; count++) {
    final matches = switch (cadence) {
      HabitCadence.weekly =>
        first != null && candidate.weekday == first.weekday,
      HabitCadence.monthly => first != null && candidate.day == first.day,
      _ => true,
    };
    if (matches &&
        candidate.isAfter(now) &&
        (first == null || !candidate.isBefore(first))) {
      return candidate;
    }
    candidate = DateTime(
      candidate.year,
      candidate.month,
      candidate.day + 1,
      hour,
      minute,
    );
  }
  throw StateError('Registered cadence cannot be projected safely.');
}
