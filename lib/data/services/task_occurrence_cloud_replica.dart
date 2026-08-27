import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/domain/entities/task_occurrence_entity.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

abstract interface class TaskOccurrenceCloudReplica {
  Future<bool> replicate({
    required String expectedUserId,
    required TaskOccurrence occurrence,
    required TaskOccurrenceTransition transition,
  });
}

class UnavailableTaskOccurrenceCloudReplica
    implements TaskOccurrenceCloudReplica {
  const UnavailableTaskOccurrenceCloudReplica();

  @override
  Future<bool> replicate({
    required String expectedUserId,
    required TaskOccurrence occurrence,
    required TaskOccurrenceTransition transition,
  }) async {
    return false;
  }
}

class SupabaseTaskOccurrenceCloudReplica implements TaskOccurrenceCloudReplica {
  SupabaseTaskOccurrenceCloudReplica(this._client);

  final sb.SupabaseClient _client;

  @override
  Future<bool> replicate({
    required String expectedUserId,
    required TaskOccurrence occurrence,
    required TaskOccurrenceTransition transition,
  }) async {
    final sb.User? user = _client.auth.currentUser;
    if (user == null || user.id != expectedUserId) {
      return false;
    }
    final Map<String, dynamic> row = TaskOccurrenceCloudRowMapper.toRow(
      expectedUserId: expectedUserId,
      occurrence: occurrence,
      transition: transition,
    );
    try {
      await _client
          .from('task_occurrences')
          .upsert(
            row,
            onConflict: 'user_id,task_id,occurrence_key,operation_id',
            ignoreDuplicates: true,
          );
      return true;
    } on Object catch (error, stackTrace) {
      Logger.errorCategory(
        'Sync Errors',
        'Task occurrence cloud replication failed',
        error,
        stackTrace,
      );
      return false;
    }
  }
}

class TaskOccurrenceCloudRowMapper {
  const TaskOccurrenceCloudRowMapper._();

  static Map<String, dynamic> toRow({
    required String expectedUserId,
    required TaskOccurrence occurrence,
    required TaskOccurrenceTransition transition,
  }) => <String, dynamic>{
    'user_id': expectedUserId,
    // One occurrence may be rescheduled more than once. The SQL primary key
    // must therefore identify the immutable transition, not only its parent
    // occurrence, while operation_id remains the replay equality key.
    'id': '${occurrence.id}::${transition.operationId}',
    'series_id': occurrence.seriesId,
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
  };
}
