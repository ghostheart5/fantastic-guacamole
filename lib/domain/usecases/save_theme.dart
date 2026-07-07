import 'package:fantastic_guacamole/domain/entities/app_theme_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_theme_repository.dart';

class SaveTheme {
  const SaveTheme(this._repository);

  final IThemeRepository _repository;

  Future<void> call(AppThemeEntity theme) => _repository.saveTheme(theme);
}
