import 'dart:convert';

import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/domain/entities/app_theme_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_theme_repository.dart';

class ThemeRepository implements IThemeRepository {
  ThemeRepository(this._store);

  static const String _key = 'app_theme_entity_v1';

  final SharedPrefsStore _store;

  static const List<AppThemeEntity> _themes = <AppThemeEntity>[
    AppThemeEntity(id: 'dark', name: 'Dark', isDark: true),
    AppThemeEntity(id: 'light', name: 'Light', isDark: false),
  ];

  @override
  Future<AppThemeEntity?> getCurrentTheme() async {
    final String? raw = _store.load(_key);
    if (raw == null || raw.trim().isEmpty) {
      return AppThemeEntity.defaultTheme();
    }
    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return AppThemeEntity(
          id: (decoded['id'] as String?) ?? 'dark',
          name: (decoded['name'] as String?) ?? 'Dark',
          isDark: (decoded['isDark'] as bool?) ?? true,
        );
      }
    } catch (_) {}
    return AppThemeEntity.defaultTheme();
  }

  @override
  Future<void> saveTheme(AppThemeEntity theme) {
    return _store.save(
      _key,
      jsonEncode(<String, dynamic>{
        'id': theme.id,
        'name': theme.name,
        'isDark': theme.isDark,
      }),
    );
  }

  @override
  Future<AppThemeEntity?> getThemeById(String id) async {
    for (final AppThemeEntity theme in _themes) {
      if (theme.id == id) {
        return theme;
      }
    }
    return null;
  }

  @override
  Future<List<AppThemeEntity>?> getAllThemes() async {
    return _themes;
  }
}
