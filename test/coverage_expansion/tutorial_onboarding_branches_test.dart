import 'package:fantastic_guacamole/tutorial/tutorial_content.dart';
import 'package:fantastic_guacamole/tutorial/tutorial_models.dart';
import 'package:fantastic_guacamole/tutorial/tutorial_progress_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('tutorial and onboarding branch coverage', () {
    test('first launch progress starts incomplete and unblocked', () {
      const TutorialProgress progress = TutorialProgress();
      expect(progress.started, isFalse);
      expect(progress.hasSeenIntro, isFalse);
      expect(progress.completedCount, 0);
      expect(progress.hasCompletedAllSteps, isFalse);
      expect(progress.completionRatio(TutorialContent.steps.length), 0.0);
    });

    test('completed, skipped, reset, and show-again transitions behave', () {
      final TutorialProgress completed = const TutorialProgress()
          .start(targetVersion: TutorialContent.contentVersion)
          .markCompleted('nexus_overview')
          .markIntroSeen();

      expect(completed.started, isTrue);
      expect(completed.hasSeenIntro, isTrue);
      expect(completed.isStepCompleted('nexus_overview'), isTrue);

      final TutorialProgress skipped = completed
          .skipStep('timeline_overview')
          .skipForever('insight_overview');
      expect(skipped.isStepDismissed('timeline_overview'), isTrue);
      expect(skipped.isStepSkippedForever('insight_overview'), isTrue);

      final TutorialProgress shownAgain = skipped.revealStep(
        'insight_overview',
      );
      expect(shownAgain.isStepDismissed('insight_overview'), isFalse);

      final TutorialProgress reset = shownAgain.reset(
        targetVersion: TutorialContent.contentVersion,
      );
      expect(reset.started, isFalse);
      expect(reset.completedCount, 0);
      expect(reset.contentVersion, TutorialContent.contentVersion);
    });

    test('missing progress fields fall back safely', () {
      final TutorialProgress sparse = TutorialProgress.fromJson(
        const <String, Object?>{},
      );
      expect(sparse.started, isFalse);
      expect(sparse.contentVersion, 1);
      expect(sparse.completedStepIds, isEmpty);
      expect(sparse.dismissedStepIds, isEmpty);
      expect(sparse.skippedForeverStepIds, isEmpty);
    });

    test('corrupted contentVersion type surfaces a parse error', () {
      expect(
        () => TutorialProgress.fromJson(<String, Object?>{
          'completed': <dynamic>['good', 42, null],
          'dismissed': <dynamic>['skip'],
          'skippedForever': <dynamic>['forever'],
          'started': 'not-bool',
          'introSeen': 'not-bool',
          'contentVersion': 'bad',
        }),
        throwsA(isA<TypeError>()),
      );
    });

    test(
      'content version migration resets started state but keeps intro flag',
      () {
        final TutorialProgress old = const TutorialProgress(
          started: true,
          hasSeenIntro: true,
          contentVersion: 1,
          completedStepIds: <String>{'legacy-step'},
        );

        final TutorialProgress migrated = old.applyContentVersion(6);
        expect(migrated.started, isFalse);
        expect(migrated.hasSeenIntro, isTrue);
        expect(migrated.completedStepIds, isEmpty);
        expect(migrated.contentVersion, 6);
      },
    );

    test('tutorial definition decoder handles valid and invalid payloads', () {
      final TutorialDefinition valid = TutorialDefinition.decode(
        '{"id":"intro","title":"Intro","version":2,"steps":[{"id":"s1","title":"Step","body":"Body","trigger":"tap","blockMode":"allowTarget"}]}',
      );
      expect(valid.id, 'intro');
      expect(valid.version, 2);
      expect(valid.steps, hasLength(1));
      expect(valid.steps.first.trigger, TutorialTriggerType.tap);

      final TutorialDefinition invalid = TutorialDefinition.decode('[]');
      expect(invalid.id, 'tutorial');
      expect(invalid.steps, isEmpty);

      final TutorialStep fallbackStep = TutorialStep.fromJson(<String, dynamic>{
        'id': 'x',
        'trigger': 'unknown',
        'blockMode': 'unknown',
      });
      expect(fallbackStep.trigger, TutorialTriggerType.manual);
      expect(fallbackStep.blockMode, TutorialBlockMode.allowTarget);
    });
  });
}
