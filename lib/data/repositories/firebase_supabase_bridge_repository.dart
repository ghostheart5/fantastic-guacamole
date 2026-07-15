import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

class FirebaseSupabaseBridgeRepository {
  FirebaseSupabaseBridgeRepository({required this._store});

  static const String _cachedFirebaseMessagingTokenKey =
      'bridge.firebase_messaging_token';
  static const Duration _minSyncInterval = Duration(minutes: 2);
  static String? _lastSyncedToken;
  static DateTime? _lastSyncedAt;

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

    final DateTime now = DateTime.now().toUtc();
    if (_lastSyncedToken == trimmed && _lastSyncedAt != null) {
      final Duration elapsed = now.difference(_lastSyncedAt!);
      if (elapsed < _minSyncInterval) {
        Logger.log(
          'Bridge',
          'Skipped Firebase->Supabase sync (source=$source): token already synced recently.',
        );
        return;
      }
    }

    final Map<String, dynamic> metadata = <String, dynamic>{
      ...?user.userMetadata,
      'firebase_messaging_token': trimmed,
      'firebase_messaging_token_source': source,
      'firebase_messaging_token_updated_at': DateTime.now()
          .toUtc()
          .toIso8601String(),
    };

    try {
      await client.auth.updateUser(sb.UserAttributes(data: metadata));
      _lastSyncedToken = trimmed;
      _lastSyncedAt = now;
      Logger.log(
        'Bridge',
        'Synced Firebase messaging token into Supabase auth metadata (source=$source).',
      );
    } on Exception catch (error) {
      if (_isOverRateLimit(error)) {
        Logger.warn(
          'Skipped Firebase->Supabase metadata update due to auth rate limit (source=$source): $error',
        );
        return;
      }
      Logger.warn(
        'Firebase->Supabase metadata sync failed non-fatally (source=$source): $error',
      );
    }
  }

  bool _isOverRateLimit(Object error) {
    final String text = error.toString().toLowerCase();
    return text.contains('over_request_rate_limit') ||
        text.contains('statuscode: 429') ||
        text.contains('request rate limit reached');
  }
}
