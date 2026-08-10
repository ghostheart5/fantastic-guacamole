import 'package:flutter_test/flutter_test.dart';

import 'package:fantastic_guacamole/tutorial/tutorial_progress_store.dart';

void main() {
  group('TutorialProgress behavior', () {
    test('start records active tutorial content version', () {
      final progress = const TutorialProgress().start(targetVersion: 7);
      final jsonText = progress.toJson().toString();

      expect(jsonText, contains('7'));
    });

    test('markCompleted records completed step id', () {
      final progress = const TutorialProgress()
          .start(targetVersion: 7)
          .markCompleted('nexus.action_hub');

      final jsonText = progress.toJson().toString();

      expect(jsonText, contains('nexus.action_hub'));
    });

    test('skipStep records skipped step id', () {
      final progress = const TutorialProgress()
          .start(targetVersion: 7)
          .skipStep('creator.quick_add');

      final jsonText = progress.toJson().toString();

      expect(jsonText, contains('creator.quick_add'));
    });

    test('skipForever records permanently hidden step id', () {
      final progress = const TutorialProgress()
          .start(targetVersion: 7)
          .skipForever('timeline.history');

      final jsonText = progress.toJson().toString();

      expect(jsonText, contains('timeline.history'));
    });

    test(
      'revealStep removes hidden step from serialized state when supported',
      () {
        final hidden = const TutorialProgress()
            .start(targetVersion: 7)
            .skipForever('coach.panel');

        final revealed = hidden.revealStep('coach.panel');

        expect(revealed.toJson().toString(), isNot(contains('coach.panel')));
      },
    );

    test('markIntroSeen changes serialized tutorial state', () {
      final before = const TutorialProgress().toJson().toString();
      final after = const TutorialProgress()
          .markIntroSeen()
          .toJson()
          .toString();

      expect(after, isNot(before));
    });

    test('reset clears prior completed and skipped step state', () {
      final progress = const TutorialProgress()
          .start(targetVersion: 1)
          .markCompleted('nexus.action_hub')
          .skipStep('creator.quick_add')
          .skipForever('timeline.history')
          .reset(targetVersion: 9);

      final jsonText = progress.toJson().toString();

      expect(jsonText, contains('9'));
      expect(jsonText, isNot(contains('nexus.action_hub')));
      expect(jsonText, isNot(contains('creator.quick_add')));
      expect(jsonText, isNot(contains('timeline.history')));
    });

    test('fromJson round trips serialized progress', () {
      final original = const TutorialProgress()
          .start(targetVersion: 7)
          .markCompleted('nexus.action_hub')
          .skipStep('creator.quick_add')
          .markIntroSeen();

      final json = Map<String, Object?>.from(original.toJson());
      final restored = TutorialProgress.fromJson(json);

      expect(restored.toJson().toString(), contains('nexus.action_hub'));
      expect(restored.toJson().toString(), contains('creator.quick_add'));
      expect(restored.toJson().toString(), contains('7'));
    });

    test('copyWith without overrides preserves value equality', () {
      final progress = const TutorialProgress()
          .start(targetVersion: 7)
          .markCompleted('nexus.action_hub');

      expect(progress.copyWith(), equals(progress));
    });
  });
}
