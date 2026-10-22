import 'dart:async';

import 'package:fantastic_guacamole/domain/entities/app_theme_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_theme_repository.dart';
import 'package:fantastic_guacamole/domain/usecases/get_current_theme.dart';
import 'package:fantastic_guacamole/domain/usecases/save_theme.dart';
import 'package:fantastic_guacamole/domain/usecases/switch_theme.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/theme_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ProviderContainer containerFor(_ThemeRepository repository) {
    final container = ProviderContainer(
      overrides: [
        getCurrentThemeUseCaseProvider.overrideWithValue(
          GetCurrentTheme(repository),
        ),
        saveThemeUseCaseProvider.overrideWithValue(SaveTheme(repository)),
        switchThemeUseCaseProvider.overrideWithValue(SwitchTheme(repository)),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('appearance changes only after storage confirms the write', () async {
    final repository = _ThemeRepository()..blockWrite = Completer<void>();
    final container = containerFor(repository);
    await container.read(currentThemeProvider.future);
    final saved = container
        .read(themeActionsProvider)
        .save(AppThemeEntity.light());
    await Future<void>.delayed(Duration.zero);
    expect(container.read(currentThemeProvider).requireValue.isDark, isTrue);
    repository.blockWrite!.complete();
    await saved;
    expect(container.read(currentThemeProvider).requireValue.isDark, isFalse);
    expect(repository.current.isDark, isFalse);
  });

  test(
    'failed save preserves appearance and does not poison the next attempt',
    () async {
      final repository = _ThemeRepository()..failNextWrite = true;
      final container = containerFor(repository);
      await container.read(currentThemeProvider.future);
      final actions = container.read(themeActionsProvider);
      await expectLater(actions.save(AppThemeEntity.light()), throwsStateError);
      expect(container.read(currentThemeProvider).requireValue.isDark, isTrue);
      expect(repository.current.isDark, isTrue);
      await actions.save(AppThemeEntity.light());
      expect(container.read(currentThemeProvider).requireValue.isDark, isFalse);
    },
  );

  test(
    'overlapping save and switch persist and publish in invocation order',
    () async {
      final repository = _ThemeRepository()..blockWrite = Completer<void>();
      final container = containerFor(repository);
      await container.read(currentThemeProvider.future);
      final actions = container.read(themeActionsProvider);
      final first = actions.save(AppThemeEntity.light());
      final second = actions.switchTo('dark');
      await Future<void>.delayed(Duration.zero);
      expect(repository.startedWrites, ['light']);
      repository.blockWrite!.complete();
      await Future.wait([first, second]);
      expect(repository.startedWrites, ['light', 'dark']);
      expect(repository.current.isDark, isTrue);
      expect(container.read(currentThemeProvider).requireValue.isDark, isTrue);
    },
  );

  test('late initial hydration cannot overwrite a newer appearance', () async {
    final repository = _ThemeRepository()
      ..blockRead = Completer<AppThemeEntity>();
    final container = containerFor(repository);
    final initial = container.read(currentThemeProvider.future);
    final saved = container
        .read(themeActionsProvider)
        .save(AppThemeEntity.light());
    await Future<void>.delayed(Duration.zero);
    expect(repository.startedWrites, isEmpty);
    repository.blockRead!.complete(AppThemeEntity.dark());
    await initial;
    await saved;
    expect(container.read(currentThemeProvider).requireValue.isDark, isFalse);
    expect(repository.current.isDark, isFalse);
  });
}

class _ThemeRepository implements IThemeRepository {
  AppThemeEntity current = AppThemeEntity.dark();
  Completer<void>? blockWrite;
  Completer<AppThemeEntity>? blockRead;
  bool failNextWrite = false;
  final List<String> startedWrites = [];

  @override
  Future<AppThemeEntity?> getCurrentTheme() async =>
      blockRead == null ? current : await blockRead!.future;

  @override
  Future<void> saveTheme(AppThemeEntity theme) async {
    startedWrites.add(theme.id);
    if (blockWrite != null) await blockWrite!.future;
    if (failNextWrite) {
      failNextWrite = false;
      throw StateError('Synthetic preference write failure');
    }
    current = theme;
  }

  @override
  Future<AppThemeEntity?> getThemeById(String id) async => switch (id) {
    'dark' => AppThemeEntity.dark(),
    'light' => AppThemeEntity.light(),
    _ => null,
  };

  @override
  Future<List<AppThemeEntity>?> getAllThemes() async => [
    AppThemeEntity.dark(),
    AppThemeEntity.light(),
  ];
}
