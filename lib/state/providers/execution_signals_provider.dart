import 'package:fantastic_guacamole/domain/entities/log_entry_entity.dart';
import 'package:fantastic_guacamole/state/providers/logs_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ExecutionSignals {
  const ExecutionSignals({
    required this.createdToday,
    required this.completedToday,
    required this.skippedToday,
    required this.delayedToday,
    required this.created7d,
    required this.completed7d,
    required this.skipped7d,
    required this.delayed7d,
  });

  final int createdToday;
  final int completedToday;
  final int skippedToday;
  final int delayedToday;

  final int created7d;
  final int completed7d;
  final int skipped7d;
  final int delayed7d;

  int get actionedToday => completedToday + skippedToday + delayedToday;
  int get actioned7d => completed7d + skipped7d + delayed7d;

  double get completionStability7d {
    final int denominator = actioned7d;
    if (denominator <= 0) {
      return 0.0;
    }
    return completed7d / denominator;
  }

  bool get hasDeferralPressure => (skippedToday + delayedToday) >= 2;
}

final executionSignalsProvider = Provider<ExecutionSignals>((Ref ref) {
  final List<LogEntryEntity> entries = ref.watch(logsProvider).entries;
  final DateTime now = DateTime.now();
  final DateTime sevenDaysAgo = now.subtract(const Duration(days: 7));

  int createdToday = 0;
  int completedToday = 0;
  int skippedToday = 0;
  int delayedToday = 0;

  int created7d = 0;
  int completed7d = 0;
  int skipped7d = 0;
  int delayed7d = 0;

  for (final LogEntryEntity entry in entries) {
    final DateTime ts = entry.timestamp;
    final String source = entry.source.trim().toLowerCase();

    final bool inToday = _isSameLocalDay(ts, now);
    final bool inLast7Days = !ts.isBefore(sevenDaysAgo);

    if (source == 'task_created') {
      if (inToday) {
        createdToday += 1;
      }
      if (inLast7Days) {
        created7d += 1;
      }
      continue;
    }

    if (source == 'completed_task' || source == 'task_completed') {
      if (inToday) {
        completedToday += 1;
      }
      if (inLast7Days) {
        completed7d += 1;
      }
      continue;
    }

    if (source == 'goal_completed') {
      if (inToday) {
        completedToday += 1;
      }
      if (inLast7Days) {
        completed7d += 1;
      }
      continue;
    }

    if (source == 'task_skipped') {
      if (inToday) {
        skippedToday += 1;
      }
      if (inLast7Days) {
        skipped7d += 1;
      }
      continue;
    }

    if (source == 'task_delayed' || source == 'task_not_completed') {
      if (inToday) {
        delayedToday += 1;
      }
      if (inLast7Days) {
        delayed7d += 1;
      }
    }
  }

  return ExecutionSignals(
    createdToday: createdToday,
    completedToday: completedToday,
    skippedToday: skippedToday,
    delayedToday: delayedToday,
    created7d: created7d,
    completed7d: completed7d,
    skipped7d: skipped7d,
    delayed7d: delayed7d,
  );
});

bool _isSameLocalDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}
