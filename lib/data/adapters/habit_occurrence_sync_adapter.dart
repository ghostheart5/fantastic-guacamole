import 'package:fantastic_guacamole/data/sync/sync_mutation_dispatcher.dart';
import 'package:fantastic_guacamole/domain/entities/habit_occurrence_entity.dart';

class HabitOccurrenceSyncAdapter {
  const HabitOccurrenceSyncAdapter(this._dispatcher);

  final SyncMutationDispatcher _dispatcher;

  Future<bool> enqueue(HabitOccurrence occurrence) => _dispatcher.enqueueUpsert(
    tableName: 'habit_occurrences',
    recordId: occurrence.id,
    payload: <String, dynamic>{
      'id': occurrence.id,
      'habit_id': occurrence.habitId,
      'period_key': occurrence.periodKey,
      'ordinal': occurrence.ordinal,
      'status': occurrence.status.name,
      'completed_at': occurrence.completedAt?.toUtc().toIso8601String(),
      'skipped_at': occurrence.skippedAt?.toUtc().toIso8601String(),
      'updated_at':
          (occurrence.completedAt ?? occurrence.skippedAt ?? DateTime.now())
              .toUtc()
              .toIso8601String(),
    },
  );
}
