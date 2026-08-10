import 'package:fantastic_guacamole/tutorial/tutorial_progress_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TutorialProgress runtime behavior', () {
    test('start sets started flag and target version', () {
      final TutorialProgress progress = const TutorialProgress().start(
        targetVersion: 9,
      );

      expect(progress.started, isTrue);
      expect(progress.contentVersion, 9);
    });

    test('markCompleted moves step into completed set and clears skips', () {
      final TutorialProgress progress = const TutorialProgress()
          .skipStep('step.a')
          .skipForever('step.a')
          .markCompleted('step.a');

      expect(progress.isStepCompleted('step.a'), isTrue);
      expect(progress.isStepDismissed('step.a'), isFalse);
      expect(progress.isStepSkippedForever('step.a'), isFalse);
    });

    test('skipStep marks step as dismissed', () {
      final TutorialProgress progress = const TutorialProgress().skipStep(
        'step.b',
      );

      expect(progress.isStepDismissed('step.b'), isTrue);
      expect(progress.dismissedCount, 1);
    });

    test('skipForever marks step as permanently skipped', () {
      final TutorialProgress progress = const TutorialProgress().skipForever(
        'step.c',
      );

      expect(progress.isStepSkippedForever('step.c'), isTrue);
      expect(progress.skippedForeverCount, 1);
    });

    test('revealStep removes dismissed and skipped forever flags', () {
      final TutorialProgress hidden = const TutorialProgress()
          .skipStep('step.d')
          .skipForever('step.d');

      final TutorialProgress revealed = hidden.revealStep('step.d');

      expect(revealed.isStepDismissed('step.d'), isFalse);
      expect(revealed.isStepSkippedForever('step.d'), isFalse);
    });

    test('markIntroSeen updates intro visibility flag', () {
      final TutorialProgress progress = const TutorialProgress()
          .markIntroSeen();
      expect(progress.hasSeenIntro, isTrue);
    });

    test('reset clears runtime state while applying target version', () {
      final TutorialProgress progress = const TutorialProgress()
          .start(targetVersion: 3)
          .markCompleted('step.e')
          .skipStep('step.f')
          .markIntroSeen()
          .reset(targetVersion: 12);

      expect(progress.started, isFalse);
      expect(progress.hasSeenIntro, isFalse);
      expect(progress.completedStepIds, isEmpty);
      expect(progress.dismissedStepIds, isEmpty);
      expect(progress.skippedForeverStepIds, isEmpty);
      expect(progress.contentVersion, 12);
    });

    test('applyContentVersion updates only version and keeps intro flag', () {
      final TutorialProgress baseline = const TutorialProgress(
        hasSeenIntro: true,
        started: true,
        contentVersion: 2,
      );

      final TutorialProgress migrated = baseline.applyContentVersion(6);

      expect(migrated.contentVersion, 6);
      expect(migrated.hasSeenIntro, isTrue);
      expect(migrated.started, isFalse);
    });

    test('toJson and fromJson roundtrip preserves state', () {
      final TutorialProgress original = const TutorialProgress()
          .start(targetVersion: 8)
          .markCompleted('step.g')
          .skipStep('step.h')
          .skipForever('step.i')
          .markIntroSeen();

      final Map<String, Object> json = original.toJson();
      final TutorialProgress restored = TutorialProgress.fromJson(json);

      expect(restored, equals(original));
      expect(restored.hashCode, equals(original.hashCode));
    });

    test('copyWith preserves unchanged fields and updates only overrides', () {
      const TutorialProgress base = TutorialProgress(
        started: true,
        hasSeenIntro: true,
        contentVersion: 4,
      );

      final TutorialProgress changed = base.copyWith(contentVersion: 11);

      expect(changed.started, isTrue);
      expect(changed.hasSeenIntro, isTrue);
      expect(changed.contentVersion, 11);
    });

    test('equality and hashCode behavior is value based', () {
      const TutorialProgress a = TutorialProgress(contentVersion: 7);
      const TutorialProgress b = TutorialProgress(contentVersion: 7);

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });
}
