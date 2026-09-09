// CHRONOSPARK-CLASS: SHIPPING | Feature: Planning evidence
import 'package:fantastic_guacamole/domain/entities/log_entry_entity.dart';

/// A bounded count of recorded behavior, not an inference about motivation.
abstract final class RecentSkipPolicy {
  static int count(Iterable<LogEntryEntity> entries, DateTime now) {
    final end = now.toUtc();
    final start = end.subtract(const Duration(days: 7));
    return entries
        .where((entry) {
          final at = entry.timestamp.toUtc();
          return entry.source == 'task_skipped' &&
              !at.isBefore(start) &&
              !at.isAfter(end);
        })
        .map((entry) => entry.id)
        .toSet()
        .length;
  }
}
