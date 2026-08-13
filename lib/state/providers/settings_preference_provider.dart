import 'dart:convert';

import 'package:fantastic_guacamole/data/di/storage_providers.dart';
import 'package:fantastic_guacamole/data/di/repositories_providers.dart';
import 'package:fantastic_guacamole/data/repositories/theme_repository.dart';
import 'package:fantastic_guacamole/domain/entities/settings_entity.dart';
import 'package:fantastic_guacamole/state/core/app_providers.dart';
import 'package:fantastic_guacamole/state/providers/intelligence_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Reads the legacy, scoped Profile sound value without writing Profile state.
final legacyProfileSoundProvider = FutureProvider<bool?>((Ref ref) async {
  final String? userId = ref.read(authUserProvider).asData?.value?.id;
  final String scope = (userId?.trim().isEmpty ?? true)
      ? 'signed_out'
      : userId!.replaceAll(RegExp('[^a-zA-Z0-9._-]'), '_');
  final String? raw = await ref
      .read(secureStoreProvider)
      .readString('profile_state_v2.$scope');
  if (raw == null || raw.trim().isEmpty) return null;
  try {
    final Object? decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) {
      return decoded['soundEnabled'] as bool?;
    }
  } on FormatException {
    // A corrupted legacy record is not migration input.
  }
  return null;
});

/// Reads the device-global legacy theme only as initial migration input.
final legacyThemeProvider = FutureProvider<String?>((Ref ref) async {
  final ThemeRepository repository = ref.read(themeRepositoryProvider);
  final legacy = await repository.getStoredTheme();
  if (legacy == null) return null;
  return legacy.isDark ? 'dark' : 'light';
});

/// Canonical application boundary for global user preferences.
///
/// It deliberately delegates persistence to [SettingsRepository], preserving
/// its scoped, serialized and cancellable write behavior.
class SettingsPreferenceController extends AsyncNotifier<SettingsEntity> {
  @override
  Future<SettingsEntity> build() async {
    final SettingsEntity current =
        await ref.read(settingsRepositoryProvider).getSettings() ??
        const SettingsEntity();
    SettingsEntity established = current;
    if (!current.soundEstablished) {
      final bool? legacySound = await ref.read(
        legacyProfileSoundProvider.future,
      );
      established = established.copyWith(
        soundEnabled: legacySound ?? current.soundEnabled,
        soundEstablished: true,
      );
    }
    if (!current.themeEstablished) {
      final String? legacyTheme = await ref.read(legacyThemeProvider.future);
      established = established.copyWith(
        themeMode: legacyTheme ?? current.themeMode,
        themeEstablished: true,
      );
    }
    if (established != current) {
      await ref.read(settingsRepositoryProvider).saveSettings(established);
    }
    _projectSound(established.soundEnabled);
    return established;
  }

  Future<void> setSoundEnabled(bool enabled) =>
      _save(state.requireValue.copyWith(soundEnabled: enabled));

  Future<void> setThemeMode(String themeMode) =>
      _save(state.requireValue.copyWith(themeMode: themeMode));

  Future<void> _save(SettingsEntity next) async {
    next.validate();
    state = AsyncData(next);
    await ref.read(settingsRepositoryProvider).saveSettings(next);
    _projectSound(next.soundEnabled);
  }

  void _projectSound(bool enabled) {
    ref.read(soundEnabledProvider.notifier).set(enabled);
  }
}

final settingsPreferencesProvider =
    AsyncNotifierProvider<SettingsPreferenceController, SettingsEntity>(
      SettingsPreferenceController.new,
    );
