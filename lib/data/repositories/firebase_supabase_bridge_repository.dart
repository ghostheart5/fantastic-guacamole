import 'dart:math';

import 'package:fantastic_guacamole/core/async/keyed_mutation_coordinator.dart';
import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

class FirebaseSupabaseBridgeRepository {
  FirebaseSupabaseBridgeRepository({
    required this._store,
    KeyedMutationCoordinator? mutationCoordinator,
  }) : _mutations = mutationCoordinator ?? KeyedMutationCoordinator.shared;

  static const String _cachedFirebaseMessagingTokenKey =
      'bridge.firebase_messaging_token';
  static const String _firebaseInstallationIdKey =
      'bridge.firebase_installation_id';
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
    await _mutations.runExclusive<void>('push-token-device', () async {
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
        final String installationId = await _ensureInstallationId();
        await client.rpc<dynamic>(
          'register_firebase_device',
          params: <String, dynamic>{
            'p_installation_id': installationId,
            'p_token': trimmed,
            'p_platform': _platformName(),
            'p_source': source,
          },
        );
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

  Future<String> _ensureInstallationId() async {
    final String? existing = await _store.readString(
      _firebaseInstallationIdKey,
    );
    if (existing != null && existing.length >= 20 && existing.length <= 128) {
      return existing;
    }
    final Random random = Random.secure();
    final List<int> bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final String hex = bytes
        .map((int byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    final String generated =
        '${hex.substring(0, 8)}-'
        '${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
    await _store.writeString(_firebaseInstallationIdKey, generated);
    return generated;
  }

  String _platformName() {
    if (kIsWeb) {
      return 'web';
    }
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      TargetPlatform.macOS => 'macos',
      TargetPlatform.windows => 'windows',
      TargetPlatform.linux => 'linux',
      TargetPlatform.fuchsia => 'linux',
    };
  }
}
