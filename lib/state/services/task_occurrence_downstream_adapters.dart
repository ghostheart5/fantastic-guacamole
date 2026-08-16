import 'package:fantastic_guacamole/data/storage/neural_history_store.dart';
import 'package:fantastic_guacamole/domain/entities/log_entry_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task_occurrence_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task_occurrence_projection_work.dart';
import 'package:fantastic_guacamole/engine/learning/neural_dump.dart';

typedef OccurrenceLearningWrite =
    Future<void> Function({required bool success, required int difficulty});
typedef OccurrenceLogWrite = Future<void> Function(LogEntryEntity entry);

/// Captures the A-bound learning write before a command crosses an await.
class TaskOccurrenceLearningAdapter {
  const TaskOccurrenceLearningAdapter(this._write);

  final OccurrenceLearningWrite _write;

  Future<bool> record(
    TaskOccurrenceTransition transition,
    TaskOccurrenceProjectionWork work,
  ) async {
    switch (transition.outcome) {
      case TaskOccurrenceOutcome.completed:
        await _write(success: true, difficulty: work.taskDifficulty);
        return true;
      case TaskOccurrenceOutcome.skipped:
        await _write(success: false, difficulty: work.taskDifficulty);
        return true;
      case TaskOccurrenceOutcome.rescheduled:
        // No existing Learning mutation represents a delay; preserve that
        // established behavior rather than inventing new scoring semantics.
        return false;
    }
  }
}

/// Writes deterministic, occurrence-derived logs through a captured A writer.
class TaskOccurrenceLogAdapter {
  const TaskOccurrenceLogAdapter(this._write);

  final OccurrenceLogWrite _write;

  Future<void> record(
    TaskOccurrenceTransition transition,
    TaskOccurrenceProjectionWork work,
  ) => _write(
    LogEntryEntity(
      id: 'task-occurrence-log:${work.id}',
      source: 'task_${transition.outcome.name}',
      message: work.taskTitle,
      timestamp: transition.at,
    ),
  );
}

/// Captures the account-scoped Neural History store; duplicate reconciliation
/// detects the deterministic entry shape before appending.
class TaskOccurrenceNeuralAdapter {
  const TaskOccurrenceNeuralAdapter(this._store);

  final NeuralHistoryStore _store;

  Future<bool> record(
    TaskOccurrenceTransition transition,
    TaskOccurrenceProjectionWork work,
  ) async {
    if (transition.outcome != TaskOccurrenceOutcome.completed) return false;
    final NeuralEntry entry = NeuralEntry(
      task: work.taskTitle,
      reasoning: 'Recorded from a completed task occurrence ${work.id}.',
      confidence: work.quality ?? 0,
      duration: work.durationSeconds ?? 0,
      quality: work.quality ?? 0,
      timestamp: transition.at,
    );
    final List<NeuralEntry> history = await _store.loadNeuralHistory();
    final bool exists = history.any(
      (NeuralEntry value) =>
          value.task == entry.task &&
          value.reasoning == entry.reasoning &&
          value.timestamp.toUtc() == entry.timestamp.toUtc(),
    );
    if (!exists) await _store.appendNeuralEntry(entry, maxEntries: 200);
    return true;
  }
}
