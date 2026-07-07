import 'package:fantastic_guacamole/domain/interfaces/i_theme_repository.dart';

class ThemeService {
  const ThemeService({required this._repository});

  final IThemeRepository _repository;

  IThemeRepository get repository => _repository;
}
