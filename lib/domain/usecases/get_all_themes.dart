import 'package:fantastic_guacamole/domain/entities/app_theme_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_theme_repository.dart';

class GetAllThemes {
  const GetAllThemes(this._repository);

  final IThemeRepository _repository;

  Future<List<AppThemeEntity>?> call() => _repository.getAllThemes();
}
