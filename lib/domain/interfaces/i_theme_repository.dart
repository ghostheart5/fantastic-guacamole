import 'package:fantastic_guacamole/core/entities/app_theme.dart';

abstract class IThemeRepository {
  Future<AppTheme?> getCurrentTheme();
  Future<void> saveTheme(AppTheme theme);
  Future<AppTheme?> getThemeById(String id);
  Future<List<AppTheme>?> getAllThemes();
}
