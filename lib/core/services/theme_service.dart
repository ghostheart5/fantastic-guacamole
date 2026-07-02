import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/core/entities/app_theme.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_theme_repository.dart';

class ThemeService {
  ThemeService(this.repo);

  final IThemeRepository repo;

  Future<AppTheme> loadTheme() async {
    final theme = await repo.getCurrentTheme();
    if (theme == null) {
      Logger.log(
        'ThemeService',
        'getCurrentTheme returned null, using default',
      );
      return AppTheme.defaultTheme();
    }
    Logger.log('ThemeService', 'Loaded theme → ${theme.id}');
    return theme;
  }

  Future<void> saveTheme(AppTheme theme) async {
    Logger.log('ThemeService', 'Saving theme → ${theme.id}');
    await repo.saveTheme(theme);
  }

  Future<AppTheme> switchTheme(String id) async {
    Logger.log('ThemeService', 'Switching theme → $id');
    final theme = await repo.getThemeById(id);
    if (theme == null) {
      Logger.log('ThemeService', "Theme '$id' not found, using default");
      return AppTheme.defaultTheme();
    }
    await repo.saveTheme(theme);
    return theme;
  }

  Future<List<AppTheme>> loadAllThemes() async {
    final themes = await repo.getAllThemes();
    if (themes == null || themes.isEmpty) {
      Logger.log('ThemeService', 'No themes found, returning default only');
      return [AppTheme.defaultTheme()];
    }
    Logger.log('ThemeService', 'Loaded ${themes.length} themes');
    return themes;
  }
}
