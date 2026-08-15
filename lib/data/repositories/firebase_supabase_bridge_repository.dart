import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

class FirebaseSupabaseBridgeRepository {
  FirebaseSupabaseBridgeRepository({required this._store});

  static const String _cachedFirebaseMessagingTokenKey =
      'bridge.firebase_messaging_token';
  static const Duration _minSyncInterval = Duration(minutes: 2);
  static final Map<String, DateTime> _lastSyncedAtByUserAndToken =
      <String, DateTime>{};
  static Future<void> _mutationTail = Future<void>.value();
  static bool _sessionWritesSuspended = false;

  final SecureStore _store;

  Future<void> cacheFirebaseMessagingToken(String token) {
    final String trimmed = token.trim();
    if (trimmed.isEmpty) {
      return Future<void>.value();
    }
    return _serialize<void>(() async {
      if (_sessionWritesSuspended) {
        return;
      }
      await _store.writeString(_cachedFirebaseMessagingTokenKey, trimmed);
    });
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

  Future<void> disassociateFirebaseMessagingToken(sb.SupabaseClient client) {
    final String? expectedUserId = client.auth.currentUser?.id;
    return _serialize<void>(() async {
      Object? associationError;
      StackTrace? associationStackTrace;
      final sb.User? user = client.auth.currentUser;
      if (expectedUserId != null && user?.id == expectedUserId) {
        try {
          await client.auth.updateUser(
            sb.UserAttributes(
              data: const <String, dynamic>{
                'firebase_messaging_token': null,
                'firebase_messaging_token_source': null,
                'firebase_messaging_token_updated_at': null,
              },
            ),
          );
        } on Object catch (error, stackTrace) {
          associationError = error;
          associationStackTrace = stackTrace;
        }
      }

      await _store.delete(_cachedFirebaseMessagingTokenKey);
      _lastSyncedAtByUserAndToken.clear();

      if (associationError != null) {
        Error.throwWithStackTrace(associationError, associationStackTrace!);
      }
    });
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
  }) {
    final String trimmed = token.trim();
    if (trimmed.isEmpty) {
      return Future<void>.value();
    }
    final String? expectedUserId = client.auth.currentUser?.id;
    return _serialize<void>(() async {
      if (_sessionWritesSuspended) {
        return;
      }
      await _store.writeString(_cachedFirebaseMessagingTokenKey, trimmed);

      final sb.User? user = client.auth.currentUser;
      if (user == null || user.id != expectedUserId) {
        Logger.log(
          'Bridge',
          'Skipped Firebase->Supabase sync (source=$source): authentication identity changed.',
        );
        return;
      }

      final DateTime now = DateTime.now().toUtc();
      final String throttleKey = _throttleKey(expectedUserId, trimmed);
      final DateTime? lastSyncedAt = _lastSyncedAtByUserAndToken[throttleKey];
      if (lastSyncedAt != null) {
        final Duration elapsed = now.difference(lastSyncedAt);
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
        if (client.auth.currentUser?.id != expectedUserId) {
          return;
        }
        await client.auth.updateUser(sb.UserAttributes(data: metadata));
        _lastSyncedAtByUserAndToken[throttleKey] = now;
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
    });
  }

  Future<void> drainMutations() => _mutationTail;

  static void suspendSessionWrites() {
    _sessionWritesSuspended = true;
  }

  static void resumeSessionWrites() {
    _sessionWritesSuspended = false;
  }

  static Future<T> _serialize<T>(Future<T> Function() action) {
    final Future<T> operation = _mutationTail.then((_) => action());
    _mutationTail = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }

  static String _throttleKey(String? userId, String token) {
    return '${userId ?? ''}\u0000$token';
  }

  bool _isOverRateLimit(Object error) {
    final String text = error.toString().toLowerCase();
    return text.contains('over_request_rate_limit') ||
        text.contains('statuscode: 429') ||
        text.contains('request rate limit reached');
  }
}
