import 'package:fantastic_guacamole/domain/entities/app_theme_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_theme_repository.dart';

/// CHRONOSPARK-CLASS: SHIPPING | Feature: Theme
///
/// Resolved by themeProvider.
class SwitchTheme {
  const SwitchTheme(this._repository);

  final IThemeRepository _repository;

  /// Returns the newly switched theme, or `null` if [id] does not match a
  /// known theme. An unknown id is a no-op: it must never overwrite the
  /// user's existing saved theme with the default.
  Future<AppThemeEntity?> call(String id) async {
    final AppThemeEntity? theme = await _repository.getThemeById(id);
    if (theme == null) {
      return null;
    }
    await _repository.saveTheme(theme);
    return theme;
  }
}
