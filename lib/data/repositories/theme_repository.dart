import 'dart:convert';

import 'package:fantastic_guacamole/core/debug/logger.dart';
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
    return await getStoredTheme() ?? AppThemeEntity.defaultTheme();
  }

  /// Reads the device-global legacy record without supplying a default.
  ///
  /// This is intentionally a migration/compatibility seam: callers that own
  /// canonical settings must be able to distinguish an absent or malformed
  /// legacy value from an explicitly stored theme.
  Future<AppThemeEntity?> getStoredTheme() async {
    final String? raw = _store.load(_key);
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        final Object? id = decoded['id'];
        final bool? isDark = decoded['isDark'] as bool?;
        if (id is! String ||
            (id != 'dark' && id != 'light') ||
            isDark == null) {
          Logger.warn('Theme payload is invalid and will be ignored.');
          return null;
        }
        return AppThemeEntity(
          id: id,
          name: (decoded['name'] as String?) ?? 'Dark',
          isDark: isDark,
        );
      }
      Logger.warn('Theme payload is not a JSON object; using default theme.');
    } on FormatException catch (error) {
      Logger.warn('Theme payload is corrupted; using default theme: $error');
    }
    return null;
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
