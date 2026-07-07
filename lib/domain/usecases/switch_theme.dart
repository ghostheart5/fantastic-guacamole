import 'package:fantastic_guacamole/domain/entities/app_theme_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_theme_repository.dart';

class SwitchTheme {
  const SwitchTheme(this._repository);

  final IThemeRepository _repository;

  Future<AppThemeEntity> call(String id) async {
    final AppThemeEntity? theme = await _repository.getThemeById(id);
    final AppThemeEntity selected = theme ?? AppThemeEntity.defaultTheme();
    await _repository.saveTheme(selected);
    return selected;
  }
}
