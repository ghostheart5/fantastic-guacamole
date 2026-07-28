import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String read(String path) {
    final file = File(path);
    if (!file.existsSync()) return '';
    return file.readAsStringSync();
  }

  bool existsAny(List<String> paths) {
    return paths.any((p) => Directory(p).existsSync() || File(p).existsSync());
  }

  String readAllDartUnder(String rootPath) {
    final root = Directory(rootPath);
    if (!root.existsSync()) return '';
    final buffer = StringBuffer();

    for (final entity in root.listSync(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        buffer.writeln(entity.path);
        buffer.writeln(entity.readAsStringSync());
      }
    }

    return buffer.toString();
  }

  group('ChronoSpark core feature architecture', () {
    test('required user-facing feature areas exist', () {
      final requiredFeatures = <String, List<String>>{
        'Nexus': [
          'lib/features/nexus',
          'lib/nexus',
        ],
        'Creator': [
          'lib/features/creator',
          'lib/creator',
        ],
        'Smart Planner': [
          'lib/features/smart_coach',
          'lib/features/coach',
          'lib/features/home',
          'lib/smart_coach',
          'lib/coach',
        ],
        'Timeline': [
          'lib/features/timeline',
          'lib/timeline',
        ],
        'Profile': [
          'lib/features/profile',
          'lib/features/settings',
          'lib/profile',
        ],
        'Progression': [
          'lib/features/progression',
          'lib/progression',
        ],
        'Trajectory Engine': [
          'lib/features/trajectory_engine',
          'lib/features/trajectory',
          'lib/trajectory_engine',
          'lib/trajectory',
        ],
        'SI Console': [
          'lib/features/si_console',
          'lib/features/si',
          'lib/si_console',
        ],
      };

      final missing = <String>[];

      requiredFeatures.forEach((name, paths) {
        if (!existsAny(paths)) {
          missing.add(name);
        }
      });

      expect(
        missing,
        isEmpty,
        reason: 'Missing required user-facing ChronoSpark feature folders: $missing',
      );
    });

    test('no backup architecture files are imported by Dart code', () {
      final allLib = readAllDartUnder('lib');

      expect(allLib.contains('.bak_arch_fix'), isFalse);
      expect(allLib.contains('.bak_arch_wording'), isFalse);
      expect(allLib.contains("import '.bak"), isFalse);
      expect(allLib.contains('import ".bak'), isFalse);
    });

    test('bottom navigation is not the primary navigation shell', () {
      final allLib = readAllDartUnder('lib');

      expect(
        allLib.contains('BottomNavigationBar('),
        isFalse,
        reason: 'BottomNavigationBar still exists. ChronoSpark should route through Nexus Action Hub.',
      );

      expect(
        allLib.contains('NavigationDestination('),
        isFalse,
        reason: 'NavigationDestination still exists. ChronoSpark should route through Nexus Action Hub.',
      );
    });

    test('Nexus Action Hub exposes required destinations', () {
      final allLib = readAllDartUnder('lib');

      final requiredLabels = <String>[
        'Coach',
        'Creator',
        'Timeline',
        'Profile',
        'Progression',
        'Trajectory',
        'SI Console',
      ];

      final missing = requiredLabels.where((label) => !allLib.contains(label)).toList();

      final bool hasActionHubMarker =
          allLib.contains('NavigationShell') ||
          allLib.contains('_showNavigationMap') ||
          allLib.contains('Action Hub');

      expect(
        hasActionHubMarker,
        isTrue,
        reason: 'Expected action-hub style navigation marker missing from source.',
      );

      expect(
        missing,
        isEmpty,
        reason: 'Nexus Action Hub appears to be missing destination labels: $missing',
      );
    });

    test('internal engine concepts are not exposed as standalone nav destinations', () {
      final allLib = readAllDartUnder('lib');

      final forbiddenScreenNames = <String>[
        'MemoriesScreen',
        'MemoryScreen',
        'InsightsScreen',
        'InsightScreen',
        'FlowMapScreen',
      ];

      final found = forbiddenScreenNames.where(allLib.contains).toList();

      expect(
        found,
        isEmpty,
        reason: 'Internal engine concepts should not be standalone user-facing screens: $found',
      );
    });
  });

  group('Tutorial feature wiring', () {
    test('tutorial feature files exist', () {
      final requiredFiles = <String>[
        'lib/tutorial/tutorial_analytics.dart',
        'lib/tutorial/tutorial_asset_loader.dart',
        'lib/tutorial/tutorial_content.dart',
        'lib/tutorial/tutorial_controller.dart',
        'lib/tutorial/tutorial_models.dart',
        'lib/tutorial/tutorial_overlay.dart',
        'lib/tutorial/tutorial_progress_store.dart',
        'lib/tutorial/tutorial_provider.dart',
        'lib/tutorial/tutorial_repository.dart',
        'lib/tutorial/tutorial_reset_service.dart',
        'lib/tutorial/tutorial_target_registry.dart',
        'lib/tutorial/widgets/micro_tutorial_card.dart',
        'lib/tutorial/widgets/show_me_again_button.dart',
      ];

      final missing = requiredFiles.where((path) => !File(path).existsSync()).toList();

      expect(
        missing,
        isEmpty,
        reason: 'Missing tutorial files: $missing',
      );
    });

    test('tutorial progress model is wired through provider and repository', () {
      final provider = read('lib/tutorial/tutorial_provider.dart');
      final repository = read('lib/tutorial/tutorial_repository.dart');
      final progress = read('lib/tutorial/tutorial_progress_store.dart');

      expect(progress.contains('class TutorialProgress'), isTrue);
      expect(provider.contains('tutorialProgressProvider'), isTrue);
      expect(provider.contains('TutorialProgressController'), isTrue);
      expect(repository.contains('loadProgress'), isTrue);
      expect(repository.contains('saveProgress'), isTrue);
      expect(repository.contains('TutorialProgress.fromJson'), isTrue);
    });

    test('tutorial overlay is wired to controller and target registry', () {
      final overlay = read('lib/tutorial/tutorial_overlay.dart');

      expect(overlay.contains('TutorialController'), isTrue);
      expect(overlay.contains('TutorialTargetRegistry'), isTrue);
      expect(overlay.contains('rectFor'), isTrue);
    });

    test('tutorial widgets call progress provider actions', () {
      final card = read('lib/tutorial/widgets/micro_tutorial_card.dart');
      final showAgain = read('lib/tutorial/widgets/show_me_again_button.dart');

      expect(card.contains('tutorialProgressProvider'), isTrue);
      expect(card.contains('startTutorial'), isTrue);
      expect(showAgain.contains('tutorialProgressProvider'), isTrue);
    });

    test('tutorial analytics is wired into provider or widgets', () {
      final provider = read('lib/tutorial/tutorial_provider.dart');
      final card = read('lib/tutorial/widgets/micro_tutorial_card.dart');

      expect(provider.contains('tutorialAnalyticsProvider'), isTrue);
      expect(card.contains('trackCardViewed'), isTrue);
    });
  });
}
