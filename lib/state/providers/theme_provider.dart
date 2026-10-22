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
  ThemeActions(this._ref);

  final Ref _ref;
  Future<void> _pending = Future<void>.value();

  Future<void> _serialize(Future<void> Function() write) {
    final operation = _pending.then((_) => write());
    // A failed preference write must neither publish an unsaved appearance nor
    // poison subsequent attempts. Keep the failure on the caller's future.
    _pending = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }

  Future<void> save(AppThemeEntity theme) => _serialize(() async {
    // Let initial hydration finish before publishing a newer saved preference.
    await _ref.read(currentThemeProvider.future);
    await _ref.read(saveThemeUseCaseProvider).call(theme);
    if (!_ref.mounted) return;
    _ref.read(currentThemeProvider.notifier).setTheme(theme);
    _ref.invalidate(availableThemesProvider);
  });

  Future<void> switchTo(String id) => _serialize(() async {
    await _ref.read(currentThemeProvider.future);
    final switched = await _ref.read(switchThemeUseCaseProvider).call(id);
    if (!_ref.mounted || switched == null) return;
    _ref.read(currentThemeProvider.notifier).setTheme(switched);
    _ref.invalidate(availableThemesProvider);
  });
}
