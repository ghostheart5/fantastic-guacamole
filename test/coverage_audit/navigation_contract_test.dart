import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('navigation contract', () {
    test('app flow exposes required user-facing routes', () {
      final file = File('lib/state/controllers/app_flow_controller.dart');
      expect(file.existsSync(), isTrue);

      final content = file.readAsStringSync();

      expect(content.contains('toNexus'), isTrue);
      expect(content.contains('toCreator'), isTrue);
      expect(content.contains('toTimeline'), isTrue);
      expect(content.contains('toProfile'), isTrue);
      expect(content.contains('toProgression'), isTrue);
      expect(content.contains('toConsole'), isTrue);
      expect(content.contains('toSmartCoach'), isTrue);
      expect(content.contains('toTrajectoryEngine'), isTrue);
    });

    test('nexus action hub exposes required blocks', () {
      final file = File('lib/features/nexus/ui/nexus_screen.widgets.dart');
      expect(file.existsSync(), isTrue);

      final content = file.readAsStringSync();
      final lower = content.toLowerCase();

      expect(
        content.contains('ACTION HUB') ||
            content.contains('Action Hub') ||
            content.contains('MISSION ROUTER') ||
            content.contains('_ActionGrid'),
        isTrue,
      );

      final List<String> routeCalls = <String>[
        'toSmartCoach(',
        'toCreator(',
        'toTimeline(',
        'toProfile(',
        'toProgression(',
        'toTrajectoryEngine(',
        'toConsole(',
      ];
      final int matchedRoutes = routeCalls.where(content.contains).length;
      expect(matchedRoutes, greaterThanOrEqualTo(6));

      final List<String> expectedLabels = <String>[
        'coach',
        'creator',
        'timeline',
        'profile',
        'ascension',
        'future vector',
        'strategic intelligence',
      ];
      final int matchedLabels = expectedLabels.where(lower.contains).length;
      expect(matchedLabels, greaterThanOrEqualTo(5));
    });
  });
}
