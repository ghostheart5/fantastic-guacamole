import 'package:supabase_flutter/supabase_flutter.dart' as sb;

class NotesRemoteGateway {
  const NotesRemoteGateway(this._client);

  final sb.SupabaseClient? _client;

  Future<void> upsert({required Map<String, dynamic> row}) async {
    final sb.SupabaseClient client = _requireClient();
    await client.from('notes').upsert(_ownedRow(client, row), onConflict: 'user_id,id');
  }

  Future<void> softDelete({required String id, required String userId}) async {
    final sb.SupabaseClient client = _requireClient();
    await client.from('notes').update(<String, dynamic>{
      'deleted_at': DateTime.now().toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id).eq('user_id', userId);
  }

  sb.SupabaseClient _requireClient() => _client ?? (throw StateError('Supabase client is not available.'));

  Map<String, dynamic> _ownedRow(sb.SupabaseClient client, Map<String, dynamic> row) {
    final String? userId = client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      throw StateError('An authenticated user is required for note sync.');
    }
    final String? claimed = row['user_id']?.toString();
    if (claimed != null && claimed.isNotEmpty && claimed != userId) {
      throw StateError('Note sync payload user does not match the active user.');
    }
    return <String, dynamic>{...row, 'user_id': userId};
  }
}
