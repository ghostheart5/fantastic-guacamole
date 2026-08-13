import 'dart:convert';

import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/data/sync/sync_mutation_dispatcher.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/domain/entities/settings_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_settings_repository.dart';

class SettingsRepository implements ISettingsRepository {
  SettingsRepository(this._store, {this._syncDispatcher});

  static const String _settingsKey = 'settings_entity_v1';
  final SharedPrefsStore _store;
  final SyncMutationDispatcher? _syncDispatcher;
  bool _cancelled = false;
  Future<void> _writeQueue = Future<void>.value();

  Future<void> cancelAndDrain() async {
    _cancelled = true;
    await _writeQueue.catchError((Object _) {});
  }

  void dispose() => _cancelled = true;

  @override
  Future<SettingsEntity?> getSettings() async {
    final String? raw = _store.load(_settingsKey);
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
      notificationsEnabled: (decoded['notificationsEnabled'] as bool?) ?? true,
      themeMode: (decoded['themeMode'] as String?) ?? 'system',
      onboardingComplete: (decoded['onboardingComplete'] as bool?) ?? false,
    );
  }

  @override
  Future<void> saveSettings(SettingsEntity settings) =>
      _serializeWrite(() async {
        await _store.save(
          _settingsKey,
          jsonEncode(<String, dynamic>{
            'soundEnabled': settings.soundEnabled,
            'notificationsEnabled': settings.notificationsEnabled,
            'themeMode': settings.themeMode,
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
      });

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
