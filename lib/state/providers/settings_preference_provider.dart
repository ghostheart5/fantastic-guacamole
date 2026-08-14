import 'package:fantastic_guacamole/data/di/repositories_providers.dart';
import 'package:fantastic_guacamole/domain/entities/settings_entity.dart';
import 'package:fantastic_guacamole/state/core/app_providers.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Legacy Profile sound records are ambiguous and must not be read as active
/// Settings input. Settings ownership migration is handled independently.
final legacyProfileSoundProvider = FutureProvider<bool?>(
  (Ref ref) async => null,
);

/// Legacy device-global theme records lack account ownership proof and must not
/// become active account Settings input.
final legacyThemeProvider = FutureProvider<String?>((Ref ref) async => null);

/// Canonical application boundary for global user preferences.
///
/// It deliberately delegates persistence to [SettingsRepository], preserving
/// its scoped, serialized and cancellable write behavior.
class SettingsPreferenceController extends AsyncNotifier<SettingsEntity> {
  @override
  Future<SettingsEntity> build() async {
    final scope = ref.watch(accountStorageScopeProvider);
    if (!scope.isAuthenticated || scope.v2Namespace == null) {
      return const SettingsEntity();
    }
    final SettingsEntity current =
        await ref.watch(settingsRepositoryProvider).getSettings() ??
        const SettingsEntity();
    SettingsEntity established = current;
    if (!current.soundEstablished) {
      established = established.copyWith(
        soundEnabled: current.soundEnabled,
        soundEstablished: true,
      );
    }
    if (!current.themeEstablished) {
      established = established.copyWith(
        themeMode: current.themeMode,
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
