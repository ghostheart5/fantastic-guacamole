import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '_support/source_test_utils.dart';

void main() {
  group('Theme contract', () {
    test('app theme sources exist and define ThemeData', () {
      final File themeFile = File('lib/theme/app_theme.dart');
      expect(themeFile.existsSync(), isTrue);
      final String text = SourceTestUtils.readText(themeFile);
      expect(text.contains('ThemeData'), isTrue);
    });

    test('app root uses themed MaterialApp setup', () {
      final File rootFile = File('lib/app/app_root.dart');
      final String text = SourceTestUtils.readText(rootFile);
      expect(text.contains('MaterialApp.router('), isTrue);
      expect(text.contains('theme:'), isTrue);
    });

    test('core screens avoid excessive raw hard-coded color literals', () {
      final List<String> offenders = <String>[];

      for (final File file in SourceTestUtils.dartFilesUnder('lib/features')) {
        final String path = SourceTestUtils.normalizePath(
          file.path,
        ).toLowerCase();
        if (!(path.contains('screen') || path.contains('view'))) {
          continue;
        }
        final String text = SourceTestUtils.readText(file);
        final int colorLiteralCount = RegExp(
          r'Color\(0x[0-9A-Fa-f]{8}\)',
        ).allMatches(text).length;
        if (colorLiteralCount > 40) {
          offenders.add(
            '${SourceTestUtils.normalizePath(file.path)}::$colorLiteralCount',
          );
        }
      }

      expect(
        offenders,
        isEmpty,
        reason: 'Potentially excessive hard-coded colors: $offenders',
      );
    });
  });
}
