import 'dart:convert';

import 'package:fantastic_guacamole/core/errors/app_exception.dart';
import 'package:fantastic_guacamole/data/storage/hive_boxes.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/data/storage/storage_keys.dart';
import 'package:fantastic_guacamole/domain/entities/settings_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task.dart';
import 'package:fantastic_guacamole/tutorial/tutorial_progress_store.dart';
import 'package:fantastic_guacamole/tutorial/tutorial_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('storage and serialization coverage', () {
    setUpAll(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await SharedPrefsService.init();
    });

    setUp(() async {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    });

    test('Hive box constants are unique and encrypted set is complete', () {
      final Set<String> allBoxes = <String>{
        HiveBoxes.tasks,
        HiveBoxes.goals,
        HiveBoxes.habits,
        HiveBoxes.projects,
        HiveBoxes.routines,
        HiveBoxes.subtasks,
        HiveBoxes.progression,
        HiveBoxes.dailyPlans,
        HiveBoxes.offlineQueue,
        HiveBoxes.notifications,
        HiveBoxes.timeline,
        HiveBoxes.cache,
      };

      expect(allBoxes.length, 12);
      expect(HiveBoxes.encryptedBoxes, allBoxes);
    });

    test('Storage key constants are stable', () {
      expect(StorageKeys.credentials, 'auth_credentials_box');
      expect(StorageKeys.session, 'auth_session_box');
      expect(StorageKeys.identity, 'identity_box');
      expect(StorageKeys.notifications, 'notifications_box');
      expect(StorageKeys.theme, 'theme_box');
      expect(StorageKeys.settings, 'settings_box');
      expect(StorageKeys.storageVersion, 'storage_version');
    });

    test('Task JSON serialization is stable for local caching', () {
      const Task task = Task(
        id: 'store-task-1',
        title: 'Serialize me',
        priority: 4,
        difficulty: 2,
        energyRequired: 3,
      );

      final Map<String, dynamic> json = task.toJson();
      final String encoded = jsonEncode(json);
      final Task restored = Task.fromJson(
        jsonDecode(encoded) as Map<String, dynamic>,
      );

      expect(restored.id, task.id);
      expect(restored.title, task.title);
      expect(restored.priority, 4);
      expect(restored.scheduledFor, isNull);
      expect(restored.subtasks, isEmpty);
    });

    test(
      'TutorialRepository handles missing progress and rejects corruption',
      () async {
        final TutorialRepository repo = const TutorialRepository();
        final SharedPreferences prefs = await SharedPreferences.getInstance();

        final TutorialProgress missing = repo.loadProgress();
        expect(missing, const TutorialProgress());

        await prefs.setString('tutorial_progress_v1', '{not-json');
        expect(repo.loadProgress, throwsA(isA<StorageException>()));
        await expectLater(
          repo.loadProgressWithVersion(contentVersion: 2),
          throwsA(isA<StorageException>()),
        );
        expect(prefs.getString('tutorial_progress_v1'), '{not-json');

        await repo.removeProgress();
        await repo.saveProgress(
          const TutorialProgress(completedStepIds: <String>{'nexus_overview'}),
        );
        expect(await repo.hasProgress(), isTrue);

        await repo.removeProgress();
        expect(await repo.hasProgress(), isFalse);
      },
    );

    test('SettingsEntity defaults and validation remain deterministic', () {
      const SettingsEntity settings = SettingsEntity();
      expect(settings.soundEnabled, isTrue);
      expect(settings.notificationsEnabled, isTrue);
      expect(settings.themeMode, 'system');
      expect(settings.onboardingComplete, isFalse);

      final SettingsEntity dark = settings.setTheme('dark');
      expect(dark.isDarkMode, isTrue);
      expect(dark.toggleNotifications().notificationsEnabled, isFalse);

      expect(
        () => const SettingsEntity(themeMode: 'broken').validate(),
        throwsStateError,
      );
      expect(() => dark.validate(), returnsNormally);
    });

    test('TutorialProgress map serializer tolerates sparse payloads', () {
      final TutorialProgress progress = TutorialProgress.fromJson(
        <String, Object?>{
          'completed': <dynamic>['a', 1],
          'dismissed': <dynamic>['b'],
          'skippedForever': <dynamic>['c'],
          'started': true,
          'introSeen': true,
          'contentVersion': 6,
        },
      );

      expect(progress.completedStepIds, const <String>{'a'});
      expect(progress.dismissedStepIds, const <String>{'b'});
      expect(progress.skippedForeverStepIds, const <String>{'c'});
      expect(progress.started, isTrue);
      expect(progress.hasSeenIntro, isTrue);
      expect(progress.contentVersion, 6);
    });
  });
}
