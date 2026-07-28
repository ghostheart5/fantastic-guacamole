import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '_support/source_test_utils.dart';

void main() {
  group('Dependency boundary contract', () {
    test('repositories/services/models avoid forbidden layer imports', () {
      final List<String> offenders = <String>[];

      for (final File file in SourceTestUtils.dartFilesUnder('lib')) {
        final String path = SourceTestUtils.normalizePath(file.path).toLowerCase();
        if (path.endsWith('/system/audio/audio_service.dart')) {
          continue;
        }
        final String text = SourceTestUtils.readText(file).toLowerCase();

        final bool isRepository = path.contains('repository');
        final bool isService = path.contains('service') && !path.contains('/ui/services/');
        final bool isModel = path.contains('model') || path.contains('/entities/');
        final bool isBarrel = path.endsWith('/models.dart') || path.endsWith('/entities.dart');
        final bool importsUi =
          RegExp(r'''import\s+['\"][^'\"]*(/ui/|/presentation/)[^'\"]*['\"]''')
            .hasMatch(text);

        if ((isRepository || isService) && importsUi) {
          offenders.add(SourceTestUtils.normalizePath(file.path));
        }

        if (isModel && !isBarrel &&
            (RegExp(r'''import\s+['\"][^'\"]*/service[^'\"]*['\"]''').hasMatch(text) ||
             RegExp(r'''import\s+['\"][^'\"]*/repository[^'\"]*['\"]''').hasMatch(text) ||
             RegExp(r'''import\s+['\"][^'\"]*/screen[^'\"]*['\"]''').hasMatch(text))) {
          offenders.add(SourceTestUtils.normalizePath(file.path));
        }
      }

      expect(offenders, isEmpty, reason: 'Architecture boundary violations detected: $offenders');
    });

    test('widget layer does not import low-level storage directly', () {
      final List<String> offenders = <String>[];

      for (final File file in SourceTestUtils.dartFilesUnder('lib')) {
        final String path = SourceTestUtils.normalizePath(file.path).toLowerCase();
        if (!(path.contains('/ui/') || path.contains('screen') || path.contains('widget'))) {
          continue;
        }
        if (path.contains('/theme/')) {
          continue;
        }

        final String text = SourceTestUtils.readText(file).toLowerCase();
        final bool directStorageImport =
            RegExp(r'''import\s+['\"][^'\"]*data/storage/[^'\"]*['\"]''')
                .hasMatch(text);
        if (path.endsWith('/features/onboarding/ui/onboarding_screen.dart')) {
          continue;
        }
        if (directStorageImport) {
          offenders.add(SourceTestUtils.normalizePath(file.path));
        }
      }

      expect(offenders, isEmpty, reason: 'UI files directly importing storage internals: $offenders');
    });

    test('internal engines avoid importing navigation shell directly', () {
      final List<String> offenders = <String>[];

      for (final File file in SourceTestUtils.dartFilesUnder('lib/engine')) {
        final String text = SourceTestUtils.readText(file).toLowerCase();
        if (text.contains('navigation_shell.dart')) {
          offenders.add(SourceTestUtils.normalizePath(file.path));
        }
      }

      expect(offenders, isEmpty, reason: 'Engine-to-navigation coupling found: $offenders');
    });
  });
}
