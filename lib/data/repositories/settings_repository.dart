import 'dart:convert';

import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/sync/sync_mutation_dispatcher.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/domain/entities/settings_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_settings_repository.dart';

class SettingsRepository implements ISettingsRepository {
  SettingsRepository(
    this._store, {
    required AccountStorageScope storageScope,
    this._syncDispatcher,
  }) : _storageKey =
           storageScope.isAuthenticated && storageScope.v2Namespace != null
           ? canonicalStorageKeyForScope(storageScope)
           : null;

  static const String _canonicalSettingsKey = 'settings_entity_v2';
  final SharedPrefsStore _store;
  final SyncMutationDispatcher? _syncDispatcher;
  final String? _storageKey;
  bool _cancelled = false;
  Future<void> _writeQueue = Future<void>.value();

  Future<void> cancelAndDrain() async {
    _cancelled = true;
    await _writeQueue.catchError((Object _) {});
  }

  void dispose() => _cancelled = true;

  static String canonicalStorageKeyForScope(AccountStorageScope scope) {
    final String? namespace = scope.v2Namespace;
    if (!scope.isAuthenticated || namespace == null) {
      throw StateError(
        'Settings persistence is unavailable outside a safe authenticated scope.',
      );
    }
    return '$_canonicalSettingsKey.$namespace';
  }

  static String canonicalStorageKeyForUser(String userId) {
    return canonicalStorageKeyForScope(
      AccountStorageScope.authenticated(userId),
    );
  }

  bool get isStorageAvailable => _storageKey != null;

  @override
  Future<SettingsEntity?> getSettings() async {
    final String? key = _storageKey;
    if (key == null) return null;
    final String? raw;
    try {
      raw = _store.load(key);
    } on Object catch (error) {
      Logger.warn(
        'Settings payload could not be read and will be ignored: $error',
      );
      return null;
    }
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException catch (error) {
      Logger.warn('Settings payload is corrupted and will be ignored: $error');
      return null;
    }
    if (decoded is! Map<String, dynamic>) {
      Logger.warn('Settings payload is not a JSON object and will be ignored.');
      return null;
    }

    return SettingsEntity(
      soundEnabled: (decoded['soundEnabled'] as bool?) ?? true,
      soundEstablished: (decoded['soundEstablished'] as bool?) ?? false,
      notificationsEnabled: (decoded['notificationsEnabled'] as bool?) ?? true,
      themeMode: (decoded['themeMode'] as String?) ?? 'system',
      themeEstablished: (decoded['themeEstablished'] as bool?) ?? false,
      onboardingComplete: (decoded['onboardingComplete'] as bool?) ?? false,
    );
  }

  @override
  Future<void> saveSettings(SettingsEntity settings) => _serializeWrite(
    () async {
      final String? key = _storageKey;
      if (key == null) {
        throw StateError(
          'Settings persistence is unavailable during the account transition.',
        );
      }
      await _store.save(
        key,
        jsonEncode(<String, dynamic>{
          'soundEnabled': settings.soundEnabled,
          'soundEstablished': settings.soundEstablished,
          'notificationsEnabled': settings.notificationsEnabled,
          'themeMode': settings.themeMode,
          'themeEstablished': settings.themeEstablished,
          'onboardingComplete': settings.onboardingComplete,
        }),
      );

      await _syncDispatcher?.enqueueUpsert(
        tableName: 'settings',
        recordId: 'default',
        payload: <String, dynamic>{
          'id': 'default',
          'sound_enabled': settings.soundEnabled,
          'notifications_enabled': settings.notificationsEnabled,
          'theme_mode': settings.themeMode,
          'onboarding_complete': settings.onboardingComplete,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
          'deleted_at': null,
        },
      );
    },
  );

  Future<void> _serializeWrite(Future<void> Function() action) {
    if (_cancelled) {
      return Future<void>.error(
        StateError('Settings mutation canceled during account transition.'),
      );
    }
    final Future<void> next = _writeQueue.then((_) => action());
    _writeQueue = next.catchError((Object _) {});
    return next;
  }
}
