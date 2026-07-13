import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

class FirebaseSupabaseBridgeRepository {
  FirebaseSupabaseBridgeRepository({required this._store});

  static const String _cachedFirebaseMessagingTokenKey =
      'bridge.firebase_messaging_token';

  final SecureStore _store;

  Future<void> cacheFirebaseMessagingToken(String token) async {
    final String trimmed = token.trim();
    if (trimmed.isEmpty) {
      return;
    }
    await _store.writeString(_cachedFirebaseMessagingTokenKey, trimmed);
  }

  Future<String?> readCachedFirebaseMessagingToken() async {
    final String? token = await _store.readString(
      _cachedFirebaseMessagingTokenKey,
    );
    if (token == null || token.trim().isEmpty) {
      return null;
    }
    return token.trim();
  }

  Future<void> syncCachedFirebaseMessagingToken(
    sb.SupabaseClient client, {
    String source = 'startup',
  }) async {
    final String? token = await readCachedFirebaseMessagingToken();
    if (token == null) {
      return;
    }
    await syncFirebaseMessagingToken(client, token, source: source);
  }

  Future<void> syncFirebaseMessagingToken(
    sb.SupabaseClient client,
    String token, {
    String source = 'startup',
  }) async {
    final String trimmed = token.trim();
    if (trimmed.isEmpty) {
      return;
    }

    await cacheFirebaseMessagingToken(trimmed);

    final sb.User? user = client.auth.currentUser;
    if (user == null) {
      Logger.log(
        'Bridge',
        'Skipped Firebase->Supabase sync (source=$source): no authenticated Supabase user.',
      );
      return;
    }

    final Map<String, dynamic> metadata = <String, dynamic>{
      ...?user.userMetadata,
      'firebase_messaging_token': trimmed,
      'firebase_messaging_token_source': source,
      'firebase_messaging_token_updated_at': DateTime.now()
          .toUtc()
          .toIso8601String(),
    };

    await client.auth.updateUser(sb.UserAttributes(data: metadata));
    Logger.log(
      'Bridge',
      'Synced Firebase messaging token into Supabase auth metadata (source=$source).',
    );
  }
}
