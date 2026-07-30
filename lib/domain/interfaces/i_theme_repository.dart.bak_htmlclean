import 'package:fantastic_guacamole/domain/entities/app_theme_entity.dart';

abstract class IThemeRepository {
  Future<AppThemeEntity?> getCurrentTheme();
  Future<void> saveTheme(AppThemeEntity theme);
  Future<AppThemeEntity?> getThemeById(String id);
  Future<List<AppThemeEntity>?> getAllThemes();
}
