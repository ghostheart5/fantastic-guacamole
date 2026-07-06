import 'package:fantastic_guacamole/domain/entities/app_theme_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_theme_repository.dart';

class GetCurrentTheme {
  const GetCurrentTheme(this._repository);

  final IThemeRepository _repository;

  Future<AppThemeEntity?> call() => _repository.getCurrentTheme();
}
