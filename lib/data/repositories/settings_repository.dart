import 'dart:convert';

import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/domain/entities/settings_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_settings_repository.dart';

class SettingsRepository implements ISettingsRepository {
  SettingsRepository(this._store);

  static const String _settingsKey = 'settings_entity_v1';
  final SecureStore _store;

  @override
  Future<SettingsEntity?> getSettings() async {
    final String? raw = await _store.readString(_settingsKey);
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }

    final Object? decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
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
    return _store.writeString(
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
