import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('navigation contract', () {
    test('app flow exposes required user-facing routes', () {
      final File file = File('lib/state/controllers/app_flow_controller.dart');
      expect(file.existsSync(), isTrue);

      final String content = file.readAsStringSync();

      expect(content.contains('toNexus'), isTrue);
      expect(content.contains('toCreator'), isTrue);
      expect(content.contains('toTimeline'), isTrue);
      expect(content.contains('toProfile'), isTrue);
      expect(content.contains('toProgression'), isTrue);
      expect(content.contains('toConsole'), isTrue);
      expect(content.contains('toSmartCoach'), isTrue);
      expect(content.contains('toTrajectoryEngine'), isTrue);
    });

    test('nexus action surfaces expose required blocks', () {
      final File file = File('lib/features/nexus/ui/nexus_screen.widgets.dart');
      expect(file.existsSync(), isTrue);

      final String content = file.readAsStringSync();

      expect(
        content.contains('ACTION HUB') ||
            content.contains('Action Hub') ||
            content.contains('_ActionGrid'),
        isTrue,
      );
      expect(content.contains('Coach'), isTrue);
      expect(content.contains('Creator'), isTrue);
      expect(content.contains('Timeline'), isTrue);
      expect(content.contains('Profile'), isTrue);
      expect(content.contains('Progression'), isTrue);
      expect(content.contains('Trajectory'), isTrue);
      expect(content.contains('SI'), isTrue);
    });
  });
}
