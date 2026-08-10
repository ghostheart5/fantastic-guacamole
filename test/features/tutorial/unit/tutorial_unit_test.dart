import 'package:fantastic_guacamole/tutorial/tutorial_content.dart';
import 'package:fantastic_guacamole/tutorial/tutorial_progress_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TutorialContent', () {
    test('step ids are unique and resolvable via byId/hasStep', () {
      final List<String> ids = TutorialContent.stepIds;

      expect(ids, isNotEmpty);
      expect(ids.toSet().length, ids.length);

      final String firstId = ids.first;
      expect(TutorialContent.hasStep(firstId), isTrue);
      expect(TutorialContent.byId(firstId), isNotNull);
      expect(TutorialContent.byId('unknown-step-id'), isNull);
    });

    test('contextual hints surface expected keys', () {
      expect(TutorialContent.hintFor('nexus'), isNotNull);
      expect(TutorialContent.hintFor('timeline_overview'), isNotNull);
      expect(TutorialContent.hintFor('not-a-context'), isNull);
    });
  });

  group('TutorialProgress', () {
    test('complete/skip/reveal transitions maintain consistent sets', () {
      const TutorialProgress initial = TutorialProgress(contentVersion: 8);

      final TutorialProgress skipped = initial.skipStep('step-a');
      expect(skipped.dismissedStepIds, contains('step-a'));
      expect(skipped.started, isTrue);

      final TutorialProgress completed = skipped.markCompleted('step-a');
      expect(completed.completedStepIds, contains('step-a'));
      expect(completed.dismissedStepIds, isNot(contains('step-a')));

      final TutorialProgress forever = completed.skipForever('step-b');
      expect(forever.skippedForeverStepIds, contains('step-b'));
      expect(forever.dismissedStepIds, isNot(contains('step-b')));

      final TutorialProgress revealed = forever.revealStep('step-b');
      expect(revealed.skippedForeverStepIds, isNot(contains('step-b')));
    });

    test('applyContentVersion resets started while preserving intro seen', () {
      final TutorialProgress progress = const TutorialProgress(
        hasSeenIntro: true,
        started: true,
        contentVersion: 3,
      ).markCompleted('step-a');

      final TutorialProgress migrated = progress.applyContentVersion(8);

      expect(migrated.contentVersion, 8);
      expect(migrated.started, isFalse);
      expect(migrated.hasSeenIntro, isTrue);
      expect(migrated.completedStepIds, isEmpty);
    });
  });
}
