import 'package:fantastic_guacamole/data/sync/sync_mutation_dispatcher.dart';
import 'package:fantastic_guacamole/domain/entities/task_occurrence_entity.dart';

/// Replicates canonical occurrence transitions independently of task rows.
class TaskOccurrenceSyncAdapter {
  const TaskOccurrenceSyncAdapter(this._dispatcher);

  final SyncMutationDispatcher _dispatcher;

  Future<bool> enqueue(TaskOccurrence occurrence) async {
    bool enqueued = true;
    for (final TaskOccurrenceTransition transition in occurrence.transitions) {
      enqueued = (await enqueueTransition(occurrence, transition)) && enqueued;
    }
    return enqueued;
  }

  Future<bool> enqueueTransition(
    TaskOccurrence occurrence,
    TaskOccurrenceTransition transition,
  ) => _dispatcher.enqueueUpsert(
    tableName: 'task_occurrences',
    recordId: recordIdFor(occurrence, transition),
    payload: <String, dynamic>{
      'id': recordIdFor(occurrence, transition),
      'task_id': occurrence.taskId,
      'occurrence_key': occurrence.occurrenceKey,
      'operation_id': transition.operationId,
      'outcome': transition.outcome.name,
      'original_schedule_identity': occurrence.initialScheduledFor
          ?.toUtc()
          .toIso8601String(),
      'resolved_at': transition.at.toUtc().toIso8601String(),
      'rescheduled_to': transition.rescheduledFor?.toUtc().toIso8601String(),
      'created_at': transition.at.toUtc().toIso8601String(),
      'updated_at': transition.at.toUtc().toIso8601String(),
    },
  );

  static String recordIdFor(
    TaskOccurrence occurrence,
    TaskOccurrenceTransition transition,
  ) => '${occurrence.id}::${transition.operationId}';
}
