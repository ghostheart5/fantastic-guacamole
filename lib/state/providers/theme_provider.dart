import 'package:fantastic_guacamole/domain/entities/app_theme_entity.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
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
    return await ref.read(getCurrentThemeUseCaseProvider).call() ??
        AppThemeEntity.defaultTheme();
  }

  void setTheme(AppThemeEntity theme) {
    state = AsyncData(theme);
  }
}

class ThemeActions {
  const ThemeActions(this._ref);

  final Ref _ref;

  Future<void> save(AppThemeEntity theme) async {
    _ref.read(currentThemeProvider.notifier).setTheme(theme);
    await _ref.read(saveThemeUseCaseProvider).call(theme);
    _ref.invalidate(currentThemeProvider);
    _ref.invalidate(availableThemesProvider);
  }

  Future<void> switchTo(String id) async {
    await _ref.read(switchThemeUseCaseProvider).call(id);
    _ref.invalidate(currentThemeProvider);
    _ref.invalidate(availableThemesProvider);
  }
}
