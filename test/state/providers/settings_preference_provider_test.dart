import 'dart:convert';
import 'dart:io';

import 'package:fantastic_guacamole/data/di/repositories_providers.dart';
import 'package:fantastic_guacamole/data/repositories/settings_repository.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/domain/entities/settings_entity.dart';
import 'package:fantastic_guacamole/state/core/app_providers.dart';
import 'package:fantastic_guacamole/state/providers/settings_preference_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'legacy sound and theme establish once, then canonical values win',
    () async {
      final _MemoryStore store = _MemoryStore();
      final SettingsRepository repository = SettingsRepository(store);

      ProviderContainer first = _container(
        repository: repository,
        legacySound: false,
        legacyTheme: 'light',
      );
      final SettingsEntity migrated = await first.read(
        settingsPreferencesProvider.future,
      );
      expect(migrated.soundEnabled, isFalse);
      expect(migrated.themeMode, 'light');
      expect(migrated.soundEstablished, isTrue);
      expect(migrated.themeEstablished, isTrue);
      expect(first.read(soundEnabledProvider), isFalse);
      first.dispose();

      ProviderContainer repeated = _container(
        repository: repository,
        legacySound: true,
        legacyTheme: 'dark',
      );
      final SettingsEntity established = await repeated.read(
        settingsPreferencesProvider.future,
      );
      expect(established.soundEnabled, isFalse);
      expect(established.themeMode, 'light');
      repeated.dispose();
    },
  );

  test('ProfileActions forwards sound changes without Profile persistence', () {
    final String source = File(
      'lib/state/providers/profile_provider.dart',
    ).readAsStringSync();
    expect(source, contains('settingsPreferencesProvider.notifier'));
    expect(source, isNot(contains('profileProvider.notifier).toggleSound')));
  });

  test('ThemeActions forwards theme changes to canonical settings', () {
    final String source = File(
      'lib/state/providers/theme_provider.dart',
    ).readAsStringSync();
    expect(source, contains('settingsPreferencesProvider.notifier'));
    expect(source, isNot(contains('saveThemeUseCaseProvider')));
  });
}

ProviderContainer _container({
  required SettingsRepository repository,
  required bool? legacySound,
  required String? legacyTheme,
}) {
  return ProviderContainer(
    overrides: [
      settingsRepositoryProvider.overrideWithValue(repository),
      legacyProfileSoundProvider.overrideWith((Ref ref) async => legacySound),
      legacyThemeProvider.overrideWith((Ref ref) async => legacyTheme),
    ],
  );
}

class _MemoryStore implements SharedPrefsStore {
  final Map<String, String> values = <String, String>{};

  @override
  Future<void> clear() async => values.clear();

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<void> init() async {}

  @override
  String? load(String key) => values[key];

  @override
  Future<void> save(String key, String value) async {
    values[key] = value;
    jsonDecode(value);
  }
}
