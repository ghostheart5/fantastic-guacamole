import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Maestro production contract', () {
    test('all flows use the runner supplied application id', () {
      final List<File> flows = Directory('maestro')
          .listSync(recursive: true)
          .whereType<File>()
          .where((File file) => file.path.endsWith('.yaml'))
          .toList(growable: false);

      expect(flows, isNotEmpty);
      for (final File flow in flows) {
        final String text = flow.readAsStringSync();
        expect(text.startsWith(r'appId: ${APP_ID}'), isTrue, reason: flow.path);
        expect(
          text.contains('com.ghostheart5.chronospark'),
          isFalse,
          reason: flow.path,
        );
      }
    });

    test('coordinate swipes use the current Maestro schema', () {
      final List<File> flows = Directory('maestro')
          .listSync(recursive: true)
          .whereType<File>()
          .where((File file) => file.path.endsWith('.yaml'))
          .toList(growable: false);

      final RegExp legacyCoordinateSwipe = RegExp(
        r'^\s+(?:from|to):\s*\r?\n\s+[xy]:\s*\d+%',
        multiLine: true,
      );
      for (final File flow in flows) {
        final String text = flow.readAsStringSync();
        expect(
          legacyCoordinateSwipe.hasMatch(text),
          isFalse,
          reason: '${flow.path} must use swipe start/end coordinates',
        );
      }
    });

    test('commands with options use object syntax', () {
      final List<File> flows = Directory('maestro')
          .listSync(recursive: true)
          .whereType<File>()
          .where((File file) => file.path.endsWith('.yaml'))
          .toList(growable: false);

      final RegExp shorthandWithOptions = RegExp(
        r'^- [a-zA-Z]+:[ \t]+[^\r\n]+\r?\n[ \t]{4}optional:',
        multiLine: true,
      );
      for (final File flow in flows) {
        final String text = flow.readAsStringSync();
        expect(
          shorthandWithOptions.hasMatch(text),
          isFalse,
          reason: '${flow.path} must use object command syntax with options',
        );
      }
    });

    test('text input closes the software keyboard before the next action', () {
      final List<File> flows = Directory('maestro')
          .listSync(recursive: true)
          .whereType<File>()
          .where((File file) => file.path.endsWith('.yaml'))
          .toList(growable: false);

      for (final File flow in flows) {
        final List<String> lines = flow.readAsLinesSync();
        for (int index = 0; index < lines.length; index++) {
          if (!lines[index].trimLeft().startsWith('- inputText:')) {
            continue;
          }
          int nextAction = index + 1;
          while (nextAction < lines.length &&
              (lines[nextAction].trim().isEmpty ||
                  lines[nextAction].trim() == '- eraseText')) {
            nextAction++;
          }
          expect(
            nextAction < lines.length &&
                lines[nextAction].trim() == '- hideKeyboard',
            isTrue,
            reason: '${flow.path}:${index + 1} must hide the keyboard',
          );
        }
      }
    });

    test('production probe is non-destructive', () {
      final String probe = File(
        'maestro/release/production_probe.yaml',
      ).readAsStringSync();
      const List<String> destructiveCommands = <String>[
        'clearState: true',
        'delete account',
        'purchase',
        'reset data',
      ];
      for (final String command in destructiveCommands) {
        expect(probe.toLowerCase().contains(command), isFalse);
      }
      expect(probe.contains('production-safe'), isTrue);
      expect(probe.contains('Mock login:'), isTrue);
    });

    test('release configuration rejects Maestro and mock access', () {
      final String env = File('lib/config/env.dart').readAsStringSync();
      final String workflow = File(
        '.github/workflows/android-release.yml',
      ).readAsStringSync();
      final String guardedBuild = File(
        'scripts/build_android_aab_prod_guarded.ps1',
      ).readAsStringSync();

      expect(
        env.contains("issues.add('Maestro test mode is enabled.')"),
        isTrue,
      );
      expect(env.contains('!kReleaseMode'), isTrue);
      expect(
        env.contains("issues.add('Mock login bypass is enabled.')"),
        isTrue,
      );
      expect(
        env.contains("issues.add('Global mock mode is enabled.')"),
        isTrue,
      );
      expect(
        guardedBuild.contains("CHRONOSPARK_ENFORCE_PROD_READINESS = 'true'"),
        isTrue,
      );
      expect(
        workflow.contains('Download exact gated AAB and manifest'),
        isTrue,
      );
    });

    test('onboarding runs in its dedicated isolated build profile', () {
      final String runner = File('scripts/run_maestro.ps1').readAsStringSync();
      final String workflow = File(
        '.github/workflows/maestro.yml',
      ).readAsStringSync();
      final String releaseSuite = File(
        'maestro/release/release_full_validation.yaml',
      ).readAsStringSync();

      expect(runner, contains("'maestro-onboarding'"));
      expect(runner, contains("MaestroMode = 'false'"));
      expect(runner, contains("GradleProfile = 'maestro'"));
      expect(runner, contains('stylus_handwriting_enabled 0'));
      expect(runner, contains("Remove-Item -LiteralPath \$resultPath -Force"));
      expect(runner, contains("\$junit.SelectNodes("));
      expect(runner, contains("\$failedCases.Count -eq 0"));
      expect(workflow, contains('-Profile maestro-onboarding'));
      expect(workflow, contains('maestro/onboarding/_suite_onboarding.yaml'));
      expect(
        workflow,
        contains('maestro/release/release_full_validation.yaml'),
      );
      expect(workflow, contains('timeout-minutes: 75'));
      expect(
        releaseSuite,
        isNot(contains('../onboarding/_suite_onboarding.yaml')),
      );
    });
  });
}
