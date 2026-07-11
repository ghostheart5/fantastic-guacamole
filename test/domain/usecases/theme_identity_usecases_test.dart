import 'package:fantastic_guacamole/domain/entities/app_theme_entity.dart';
import 'package:fantastic_guacamole/domain/entities/identity_profile_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_identity_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_theme_repository.dart';
import 'package:fantastic_guacamole/domain/usecases/get_all_themes.dart';
import 'package:fantastic_guacamole/domain/usecases/get_current_theme.dart';
import 'package:fantastic_guacamole/domain/usecases/get_identity_profile.dart';
import 'package:fantastic_guacamole/domain/usecases/save_identity_profile.dart';
import 'package:fantastic_guacamole/domain/usecases/save_theme.dart';
import 'package:fantastic_guacamole/domain/usecases/switch_theme.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('theme usecases', () {
    late _FakeThemeRepository repository;

    setUp(() {
      repository = _FakeThemeRepository();
    });

    test('get/save/switch theme use the repository contract', () async {
      expect(await GetCurrentTheme(repository).call(), isNull);

      const AppThemeEntity dark = AppThemeEntity(
        id: 'dark',
        name: 'Dark',
        isDark: true,
      );
      await SaveTheme(repository).call(dark);
      expect((await GetCurrentTheme(repository).call())?.id, 'dark');

      final themes = await GetAllThemes(repository).call();
      expect(themes, isNotNull);
      expect(
        themes!.map((AppThemeEntity theme) => theme.id),
        containsAll(<String>['dark', 'light']),
      );

      final AppThemeEntity switched = await SwitchTheme(
        repository,
      ).call('light');
      expect(switched.id, 'light');
      expect((await GetCurrentTheme(repository).call())?.id, 'light');
    });
  });

  group('identity profile usecases', () {
    late _FakeIdentityRepository repository;

    setUp(() {
      repository = _FakeIdentityRepository();
    });

    test('get/save identity profile use the repository contract', () async {
      expect(await GetIdentityProfile(repository).call(), isNull);

      const IdentityProfileEntity profile = IdentityProfileEntity(
        disciplineIdentity: 0.4,
        focusIdentity: 0.6,
        growthIdentity: 0.8,
      );
      await SaveIdentityProfile(repository).call(profile);

      final IdentityProfileEntity? restored = await GetIdentityProfile(
        repository,
      ).call();
      expect(restored, isNotNull);
      expect(restored!.disciplineIdentity, 0.4);
      expect(restored.focusIdentity, 0.6);
      expect(restored.growthIdentity, 0.8);
    });
  });
}

class _FakeThemeRepository implements IThemeRepository {
  AppThemeEntity? _current;
  final List<AppThemeEntity> _themes = const <AppThemeEntity>[
    AppThemeEntity(id: 'dark', name: 'Dark', isDark: true),
    AppThemeEntity(id: 'light', name: 'Light', isDark: false),
  ];

  @override
  Future<List<AppThemeEntity>?> getAllThemes() async => _themes;

  @override
  Future<AppThemeEntity?> getCurrentTheme() async => _current;

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
  Future<void> saveTheme(AppThemeEntity theme) async {
    _current = theme;
  }
}

class _FakeIdentityRepository implements IIdentityRepository {
  String? _identityId;
  IdentityProfileEntity? _profile;

  @override
  Future<String?> getIdentityId() async => _identityId;

  @override
  Future<IdentityProfileEntity?> getIdentityProfile() async => _profile;

  @override
  Future<void> saveIdentityId(String id) async {
    _identityId = id;
  }

  @override
  Future<void> saveIdentityProfile(IdentityProfileEntity profile) async {
    _profile = profile;
  }
}
