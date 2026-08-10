import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/tutorial/tutorial_progress_store.dart';
import 'package:fantastic_guacamole/tutorial/tutorial_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TutorialRepository behavior', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await SharedPrefsService.init();
      await const TutorialRepository().resetProgress();
    });

    test('loadProgress returns default when no data exists', () {
      final TutorialProgress progress = const TutorialRepository()
          .loadProgress();

      expect(progress, equals(const TutorialProgress()));
      expect(progress.contentVersion, 1);
    });

    test('saveProgress then loadProgress returns equivalent state', () async {
      final TutorialRepository repository = const TutorialRepository();
      final TutorialProgress source = const TutorialProgress()
          .start(targetVersion: 5)
          .markCompleted('step.one')
          .skipStep('step.two')
          .markIntroSeen();

      await repository.saveProgress(source);
      final TutorialProgress loaded = repository.loadProgress();

      expect(loaded, equals(source));
      expect(loaded.toJson(), equals(source.toJson()));
    });

    test('corrupt json falls back safely without throwing', () async {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('tutorial_progress_v1', '{not valid json');

      final TutorialProgress loaded = const TutorialRepository().loadProgress();

      expect(loaded, equals(const TutorialProgress()));
    });

    test(
      'loadProgressWithVersion migrates contentVersion and persists',
      () async {
        final TutorialRepository repository = const TutorialRepository();
        await repository.saveProgress(
          const TutorialProgress(contentVersion: 1).markIntroSeen(),
        );

        final TutorialProgress migrated = await repository
            .loadProgressWithVersion(contentVersion: 7);

        expect(migrated.contentVersion, 7);
        final TutorialProgress persisted = repository.loadProgress();
        expect(persisted.contentVersion, 7);
      },
    );
  });
}
