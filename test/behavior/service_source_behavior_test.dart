import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '_support/source_test_utils.dart';

void main() {
  bool isConcreteServicePath(String normalizedPath) {
    final String lowerPath = normalizedPath.toLowerCase();
    if (!lowerPath.endsWith('.dart')) {
      return false;
    }
    if (lowerPath.endsWith('.g.dart') || lowerPath.endsWith('.freezed.dart')) {
      return false;
    }
    if (lowerPath.contains('/test/')) {
      return false;
    }

    final bool inServiceLayer = lowerPath.contains('/services/');
    final bool namedService = lowerPath.endsWith('_service.dart');
    final bool isContainerOnly =
        lowerPath.endsWith('_dependencies.dart') ||
        lowerPath.endsWith('_events.dart') ||
        lowerPath.endsWith('/services.dart') ||
        lowerPath.contains('/di/') ||
        lowerPath.endsWith('providers.dart');
    return (inServiceLayer || namedService) && !isContainerOnly;
  }

  group('Service source behavior', () {
    test('service files expose real methods and are not empty shells', () {
      final List<String> offenders = <String>[];
      final RegExp methodPattern = RegExp(
        r'\b[a-zA-Z_]\w*\s*\([^;{}]*\)\s*(?:async\s*)?(?:=>|\{|;)',
      );

      for (final File file in SourceTestUtils.dartFilesUnder('lib')) {
        final String path = SourceTestUtils.normalizePath(
          file.path,
        ).toLowerCase();
        if (!isConcreteServicePath(path)) {
          continue;
        }

        final String text = SourceTestUtils.readText(file);
        final bool hasMethod = methodPattern.hasMatch(text);
        final bool hasGetter = RegExp(
          r'\bget\s+[a-zA-Z_]\w*\s*=>',
        ).hasMatch(text);
        final bool emptyClass = RegExp(r'class\s+\w+\s*\{\s*\}').hasMatch(text);
        if ((!hasMethod && !hasGetter) || emptyClass) {
          offenders.add(SourceTestUtils.normalizePath(file.path));
        }
      }

      expect(
        offenders,
        isEmpty,
        reason: 'Service files with insufficient behavior: $offenders',
      );
    });

    test(
      'service files avoid importing screens/widgets unless explicitly UI services',
      () {
        final List<String> offenders = <String>[];

        for (final File file in SourceTestUtils.dartFilesUnder('lib')) {
          final String path = SourceTestUtils.normalizePath(file.path);
          final String lowerPath = path.toLowerCase();
          if (!isConcreteServicePath(lowerPath)) {
            continue;
          }

          final String text = SourceTestUtils.readText(file).toLowerCase();
          final bool importsUi =
              text.contains('/screen') ||
              text.contains('/page') ||
              text.contains('/widget');
          final bool explicitUiService =
              lowerPath.contains('/ui/') ||
              lowerPath.contains('/presentation/');
          if (importsUi && !explicitUiService) {
            offenders.add(path);
          }
        }

        expect(
          offenders,
          isEmpty,
          reason: 'Non-UI services importing UI layers: $offenders',
        );
      },
    );

    test(
      'auth and storage service paths include expected operational verbs when present',
      () {
        final String all = SourceTestUtils.readAllConcatenated(
          'lib',
        ).toLowerCase();

        final bool authExists =
            all.contains('auth_service') || all.contains('authservice');
        if (authExists) {
          expect(all.contains('signout'), isTrue);
          expect(all.contains('signin') || all.contains('sign_in'), isTrue);
          expect(all.contains('restore'), isTrue);
        }

        final bool storageExists =
            all.contains('hive_service') ||
            all.contains('shared_prefs_service');
        if (storageExists) {
          expect(all.contains('init('), isTrue);
          expect(all.contains('save(') || all.contains('write('), isTrue);
          expect(all.contains('load(') || all.contains('read('), isTrue);
        }
      },
    );
  });
}
