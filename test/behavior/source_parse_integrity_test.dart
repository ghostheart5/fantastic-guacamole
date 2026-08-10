import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '_support/source_test_utils.dart';

void main() {
  group('Source parse integrity', () {
    test(
      'all lib dart files parse as strict UTF-8 and avoid mojibake markers',
      () {
        final List<String> offenders = <String>[];
        const List<String> badTokens = <String>[
          '�',
          'Ã',
          'Â',
          'â€™',
          'â€œ',
          'â€',
          'ðŸ',
        ];

        for (final File file in SourceTestUtils.dartFilesUnder('lib')) {
          try {
            final String text = SourceTestUtils.readUtf8Strict(file);
            if (badTokens.any(text.contains)) {
              offenders.add(SourceTestUtils.normalizePath(file.path));
            }
          } catch (_) {
            offenders.add(SourceTestUtils.normalizePath(file.path));
          }
        }

        expect(
          offenders,
          isEmpty,
          reason: 'UTF-8 or mojibake issues detected: $offenders',
        );
      },
    );

    test('lib has no merge markers backup imports or test imports', () {
      final List<String> offenders = <String>[];
      final List<File> allFiles = SourceTestUtils.filesUnder('lib');

      for (final File file in allFiles) {
        final String normalized = SourceTestUtils.normalizePath(
          file.path,
        ).toLowerCase();

        if (!normalized.endsWith('.dart')) {
          continue;
        }

        final String text = SourceTestUtils.readText(file);
        if (text.contains('<<<<<<<') ||
            text.contains('=======') ||
            text.contains('>>>>>>>')) {
          offenders.add(normalized);
          continue;
        }

        final String lowerText = text.toLowerCase();
        if (RegExp(
              r'''import\s+['"][^'"]+\.bak[^'"]*['"]''',
            ).hasMatch(lowerText) ||
            lowerText.contains('package:flutter_test')) {
          offenders.add(normalized);
        }
      }

      expect(
        offenders,
        isEmpty,
        reason: 'Source integrity violations: $offenders',
      );
    });
  });
}
