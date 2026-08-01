import 'package:supabase_flutter/supabase_flutter.dart' as sb;

class GoalsRemoteGateway {
  const GoalsRemoteGateway(this._client);

  final sb.SupabaseClient? _client;

  Future<void> upsert({required Map<String, dynamic> row}) async {
    final sb.SupabaseClient client = _requireClient();
    await client.from('goals').upsert(row);
  }

  Future<void> softDelete({
    required String id,
    required String userId,
    DateTime? at,
  }) async {
    final sb.SupabaseClient client = _requireClient();
    await client
        .from('goals')
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
        .from('goals')
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
}
