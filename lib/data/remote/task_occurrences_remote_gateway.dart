import 'package:supabase_flutter/supabase_flutter.dart' as sb;

class TaskOccurrencesRemoteGateway {
  const TaskOccurrencesRemoteGateway(
    this._client, {
    this.upsertOverride,
  });

  final sb.SupabaseClient? _client;
  /// Local test transport only; production leaves this null and uses Supabase.
  final Future<void> Function(Map<String, dynamic> row)? upsertOverride;

  Future<void> upsert({required Map<String, dynamic> row}) async {
    final Future<void> Function(Map<String, dynamic> row)? override =
        upsertOverride;
    if (override != null) {
      await override(Map<String, dynamic>.from(row));
      return;
    }
    final sb.SupabaseClient client =
        _client ?? (throw StateError('Supabase client is not available.'));
    final String? userId = client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      throw StateError(
        'An authenticated user is required for occurrence sync.',
      );
    }
    final String? claimed = row['user_id']?.toString();
    if (claimed != null && claimed.isNotEmpty && claimed != userId) {
      throw StateError(
        'Task occurrence sync payload user does not match the active user.',
      );
    }
    await client.from('task_occurrences').upsert(<String, dynamic>{
      ...row,
      'user_id': userId,
    }, onConflict: 'user_id,id');
  }
}
