import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../behavior/_support/source_test_utils.dart';

void main() {
  group('Storage release protection', () {
    test('storage init and fallback paths exist', () {
      final File hive = File('lib/data/storage/hive_service.dart');
      final File prefs = File('lib/data/storage/shared_prefs_service.dart');

      expect(hive.existsSync(), isTrue);
      expect(prefs.existsSync(), isTrue);

      final String hiveText = SourceTestUtils.readText(hive);
      final String prefsText = SourceTestUtils.readText(prefs);

      expect(hiveText.contains('Future<void> init('), isTrue);
      expect(hiveText.contains('timeout('), isTrue);
      expect(hiveText.contains('catch'), isTrue);
      expect(prefsText.contains('Future<void> init('), isTrue);
      expect(prefsText.contains('catch'), isTrue);
      expect(prefsText.contains('StateError'), isTrue);
    });

    test('storage source avoids UI imports and has migration-friendly behavior', () {
      final List<String> offenders = <String>[];

      for (final File file in SourceTestUtils.dartFilesUnder('lib/data/storage')) {
        final String path = SourceTestUtils.normalizePath(file.path);
        final String text = SourceTestUtils.readText(file).toLowerCase();
        if (text.contains('/ui/') || text.contains('material.dart')) {
          offenders.add(path);
        }
      }

      expect(offenders, isEmpty, reason: 'Storage should not depend on UI layers: $offenders');

      final String storageText = SourceTestUtils.readAllConcatenated('lib/data/storage').toLowerCase();
      expect(storageText.contains('fallback') || storageText.contains('legacy') || storageText.contains('migration') || storageText.contains('encrypted open failed'), isTrue);
    });

    test('storage source has no obvious infinite init loops', () {
      final String text = SourceTestUtils.readText(File('lib/data/storage/hive_service.dart')).toLowerCase();
      expect(text.contains('while (true)'), isFalse);
      expect(text.contains('for (;;)'), isFalse);
    });
  });
}
