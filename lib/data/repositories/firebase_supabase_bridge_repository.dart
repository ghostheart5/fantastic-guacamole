import 'package:fantastic_guacamole/core/async/keyed_mutation_coordinator.dart';
import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

class FirebaseSupabaseBridgeRepository {
  FirebaseSupabaseBridgeRepository({
    required this._store,
    KeyedMutationCoordinator? mutationCoordinator,
  }) : _mutations = mutationCoordinator ?? KeyedMutationCoordinator.shared;

  static const String _cachedFirebaseMessagingTokenKey =
      'bridge.firebase_messaging_token';
  static const Duration _minSyncInterval = Duration(minutes: 2);
  final SecureStore _store;
  final KeyedMutationCoordinator _mutations;
  final Map<String, ({String token, DateTime syncedAt})> _lastSyncByOwner =
      <String, ({String token, DateTime syncedAt})>{};

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

    final String ownerId = user.id;
    await _mutations.runExclusive<void>('push-token-owner:$ownerId', () async {
      if (client.auth.currentUser?.id != ownerId) {
        Logger.warn(
          'Skipped Firebase->Supabase sync (source=$source): authenticated owner changed.',
        );
        return;
      }

      final DateTime now = DateTime.now().toUtc();
      final ({String token, DateTime syncedAt})? last =
          _lastSyncByOwner[ownerId];
      if (last != null &&
          last.token == trimmed &&
          now.difference(last.syncedAt) < _minSyncInterval) {
        Logger.log(
          'Bridge',
          'Skipped Firebase->Supabase sync (source=$source): token already synced recently for this owner.',
        );
        return;
      }

      try {
        await client.from('user_push_tokens').upsert(<String, dynamic>{
          'user_id': ownerId,
          'token': trimmed,
          'source': source,
          'updated_at': now.toIso8601String(),
        }, onConflict: 'user_id,token');
        _lastSyncByOwner[ownerId] = (token: trimmed, syncedAt: now);
        Logger.log(
          'Bridge',
          'Synced Firebase messaging token for the authenticated Supabase owner (source=$source).',
        );
      } on Exception catch (error) {
        if (_isOverRateLimit(error)) {
          Logger.warn(
            'Skipped Firebase->Supabase token update due to rate limit (source=$source): $error',
          );
          return;
        }
        Logger.warn(
          'Firebase->Supabase token sync failed non-fatally (source=$source): $error',
        );
      }
    });
  }

  bool _isOverRateLimit(Object error) {
    final String text = error.toString().toLowerCase();
    return text.contains('over_request_rate_limit') ||
        text.contains('statuscode: 429') ||
        text.contains('request rate limit reached');
  }
}
