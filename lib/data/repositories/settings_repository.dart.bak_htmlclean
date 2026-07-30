import 'dart:convert';

import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/domain/entities/settings_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_settings_repository.dart';

class SettingsRepository implements ISettingsRepository {
  SettingsRepository(this._store);

  static const String _settingsKey = 'settings_entity_v1';
  final SharedPrefsStore _store;

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
  Future<void> saveSettings(SettingsEntity settings) {
    return _store.save(
      _settingsKey,
      jsonEncode(<String, dynamic>{
        'soundEnabled': settings.soundEnabled,
        'notificationsEnabled': settings.notificationsEnabled,
        'themeMode': settings.themeMode,
        'onboardingComplete': settings.onboardingComplete,
      }),
    );
  }
}
