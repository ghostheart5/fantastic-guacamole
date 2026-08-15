import 'package:fantastic_guacamole/domain/entities/app_theme_entity.dart';
import 'package:fantastic_guacamole/domain/entities/settings_entity.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/settings_preference_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final currentThemeProvider =
    AsyncNotifierProvider<CurrentThemeController, AppThemeEntity>(
      CurrentThemeController.new,
    );

final availableThemesProvider = FutureProvider<List<AppThemeEntity>>((
  ref,
) async {
  return await ref.read(getAllThemesUseCaseProvider).call() ??
      <AppThemeEntity>[];
});

final themeActionsProvider = Provider<ThemeActions>((ref) {
  return ThemeActions(ref);
});

class CurrentThemeController extends AsyncNotifier<AppThemeEntity> {
  @override
  Future<AppThemeEntity> build() async {
    final AsyncValue<SettingsEntity> settings = ref.watch(
      settingsPreferencesProvider,
    );
    final String mode = await settings.when(
      data: (value) async => value.themeMode,
      loading: () async =>
          (await ref.watch(settingsPreferencesProvider.future)).themeMode,
      error: (Object error, StackTrace stackTrace) =>
          Error.throwWithStackTrace(error, stackTrace),
    );
    return mode == 'light' ? AppThemeEntity.light() : AppThemeEntity.dark();
  }

  void setTheme(AppThemeEntity theme) {
    state = AsyncData(theme);
  }
}

class ThemeActions {
  const ThemeActions(this._ref);

  final Ref _ref;

  Future<void> save(AppThemeEntity theme) async {
    await _ref
        .read(settingsPreferencesProvider.notifier)
        .setThemeMode(theme.isDark ? 'dark' : 'light');
    _ref.read(currentThemeProvider.notifier).setTheme(theme);
    _ref.invalidate(currentThemeProvider);
    _ref.invalidate(availableThemesProvider);
  }

  Future<void> switchTo(String id) async {
    switch (id) {
      case 'light':
        await save(AppThemeEntity.light());
      case 'dark':
        await save(AppThemeEntity.dark());
    }
  }
}
