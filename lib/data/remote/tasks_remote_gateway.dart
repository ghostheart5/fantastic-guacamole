import 'package:supabase_flutter/supabase_flutter.dart' as sb;

class TasksRemoteGateway {
  const TasksRemoteGateway(this._client);

  final sb.SupabaseClient? _client;

  Future<void> upsert({required Map<String, dynamic> row}) async {
    final sb.SupabaseClient client = _requireClient();
    await client.from('tasks').upsert(
      _ownedRow(client, row),
      onConflict: 'user_id,id',
    );
  }

  Future<void> softDelete({
    required String id,
    required String userId,
    DateTime? at,
  }) async {
    final sb.SupabaseClient client = _requireClient();
    await client
        .from('tasks')
        .update(<String, dynamic>{
          'deleted_at': (at ?? DateTime.now().toUtc()).toIso8601String(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', id)
        .eq('user_id', userId);
  }

  Future<List<Map<String, dynamic>>> fetchUpdatedSince({
    required String userId,
    required DateTime since,
    int limit = 500,
  }) async {
    final sb.SupabaseClient client = _requireClient();
    final List<dynamic> rows = await client
        .from('tasks')
        .select()
        .eq('user_id', userId)
        .gte('updated_at', since.toIso8601String())
        .order('updated_at', ascending: true)
        .limit(limit);
    return rows
        .whereType<Map<dynamic, dynamic>>()
        .map((Map<dynamic, dynamic> row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }

  sb.SupabaseClient _requireClient() {
    final sb.SupabaseClient? client = _client;
    if (client == null) {
      throw StateError('Supabase client is not available.');
    }
    return client;
  }

  Map<String, dynamic> _ownedRow(
    sb.SupabaseClient client,
    Map<String, dynamic> row,
  ) {
    final String? userId = client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      throw StateError('An authenticated user is required for task sync.');
    }
    final String? claimedUserId = row['user_id']?.toString();
    if (claimedUserId != null && claimedUserId.isNotEmpty && claimedUserId != userId) {
      throw StateError('Task sync payload user does not match the active user.');
    }
    return <String, dynamic>{...row, 'user_id': userId};
  }
}
