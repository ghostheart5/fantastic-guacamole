import 'package:fantastic_guacamole/domain/entities/completion_event_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task_occurrence_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_completion_event_repository.dart';

/// Compatibility-only completion-ledger projection for TaskOccurrence.
///
/// Deleting one of these records never changes Task or TaskOccurrence state.
class TaskOccurrenceCompletionAdapter {
  const TaskOccurrenceCompletionAdapter(this._completionEvents);

  final ICompletionEventRepository _completionEvents;

  Future<void> record(TaskOccurrence occurrence, {String? source}) async {
    for (final TaskOccurrenceTransition transition in occurrence.transitions) {
      await recordTransition(occurrence, transition, source: source);
    }
  }

  Future<void> recordTransition(
    TaskOccurrence occurrence,
    TaskOccurrenceTransition transition, {
    String? source,
  }) async {
    final String id = eventIdFor(occurrence, transition);
    if (_completionEvents.getEvents().any(
      (CompletionEventEntity event) => event.id == id,
    )) {
      return;
    }
    await _completionEvents.addEvent(
      CompletionEventEntity(
        id: id,
        eventType: _eventTypeFor(transition.outcome),
        eventAt: transition.at.toUtc(),
        taskId: occurrence.taskId,
        source: source ?? 'task_occurrence_projection',
        metadata: <String, dynamic>{
          'occurrenceId': occurrence.id,
          'occurrenceKey': occurrence.occurrenceKey,
          'operationId': transition.operationId,
          'outcome': transition.outcome.name,
          'rescheduledTo': transition.rescheduledFor?.toUtc().toIso8601String(),
        },
      ),
    );
  }

  static String eventIdFor(
    TaskOccurrence occurrence,
    TaskOccurrenceTransition transition,
  ) => 'task-occurrence:${occurrence.id}:${transition.operationId}';

  static CompletionEventType _eventTypeFor(TaskOccurrenceOutcome outcome) =>
      switch (outcome) {
        TaskOccurrenceOutcome.completed => CompletionEventType.completed,
        TaskOccurrenceOutcome.skipped => CompletionEventType.skipped,
        TaskOccurrenceOutcome.rescheduled => CompletionEventType.rescheduled,
      };
}
