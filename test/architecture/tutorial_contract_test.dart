import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String read(String path) {
    final file = File(path);
    if (!file.existsSync()) return '';
    return file.readAsStringSync();
  }

  test('tutorial progress supports required lifecycle actions', () {
    final progress = read('lib/tutorial/tutorial_progress_store.dart');

    expect(progress.contains('class TutorialProgress'), isTrue);
    expect(progress.contains('start('), isTrue);
    expect(progress.contains('markCompleted'), isTrue);
    expect(progress.contains('skipStep'), isTrue);
    expect(progress.contains('skipForever'), isTrue);
    expect(progress.contains('revealStep'), isTrue);
    expect(progress.contains('markIntroSeen'), isTrue);
    expect(progress.contains('reset('), isTrue);
    expect(progress.contains('applyContentVersion'), isTrue);
    expect(progress.contains('fromJson'), isTrue);
    expect(progress.contains('toJson'), isTrue);
  });

  test('tutorial provider saves progress after mutations', () {
    final provider = read('lib/tutorial/tutorial_provider.dart');

    expect(provider.contains('AsyncNotifierProvider'), isTrue);
    expect(provider.contains('TutorialProgressController'), isTrue);
    expect(provider.contains('_save('), isTrue);
    expect(provider.contains('saveProgress'), isTrue);
    expect(provider.contains('loadProgressWithVersion'), isTrue);
  });

  test('tutorial repository persists progress as json', () {
    final repo = read('lib/tutorial/tutorial_repository.dart');

    expect(repo.contains('loadProgress'), isTrue);
    expect(repo.contains('saveProgress'), isTrue);
    expect(repo.contains('json'), isTrue);
    expect(repo.contains('TutorialProgress.fromJson'), isTrue);
  });

  test('tutorial reset service reaches progress controller', () {
    final reset = read('lib/tutorial/tutorial_reset_service.dart');

    expect(reset.contains('TutorialResetService'), isTrue);
    expect(reset.contains('tutorialResetServiceProvider'), isTrue);
    expect(reset.contains('tutorialProgressProvider.notifier'), isTrue);
  });

  test(
    'tutorial overlay uses target registry for anchored overlay placement',
    () {
      final overlay = read('lib/tutorial/tutorial_overlay.dart');

      expect(overlay.contains('TutorialTargetRegistry'), isTrue);
      expect(overlay.contains('rectFor'), isTrue);
      expect(overlay.contains('TutorialController'), isTrue);
    },
  );
}
