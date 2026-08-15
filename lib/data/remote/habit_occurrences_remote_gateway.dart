import 'package:supabase_flutter/supabase_flutter.dart' as sb;

class HabitOccurrencesRemoteGateway {
  const HabitOccurrencesRemoteGateway(this._client);

  final sb.SupabaseClient? _client;

  Future<void> upsert({required Map<String, dynamic> row}) async {
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
        'Occurrence sync payload user does not match the active user.',
      );
    }
    await client.from('habit_occurrences').upsert(<String, dynamic>{
      ...row,
      'user_id': userId,
    }, onConflict: 'user_id,id');
  }
}
