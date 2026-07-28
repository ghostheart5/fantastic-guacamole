import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../behavior/_support/source_test_utils.dart';

void main() {
  group('Trajectory engine release protection', () {
    test('trajectory engine source exists with projection language', () {
      final Directory dir = Directory('lib/features/trajectory_engine');
      expect(dir.existsSync(), isTrue);
      final String text = SourceTestUtils.readAllConcatenated('lib/features/trajectory_engine').toLowerCase();

      expect(text.contains('trajectory') || text.contains('future') || text.contains('momentum'), isTrue);
    });

    test('trajectory calculation boundaries avoid direct ui dependency in providers/services', () {
      final List<String> offenders = <String>[];
      for (final File file in SourceTestUtils.dartFilesUnder('lib/state/providers')) {
        final String path = SourceTestUtils.normalizePath(file.path).toLowerCase();
        if (!path.contains('trajectory')) {
          continue;
        }
        final String text = SourceTestUtils.readText(file).toLowerCase();
        if (text.contains('/ui/')) {
          offenders.add(path);
        }
      }

      expect(offenders, isEmpty, reason: 'Trajectory providers should not import UI directly: $offenders');
    });

    test('trajectory widget source does not make network calls in build', () {
      final File screen = File('lib/features/trajectory_engine/ui/trajectory_engine_screen.dart');
      expect(screen.existsSync(), isTrue);
      final String text = SourceTestUtils.readText(screen);

      final int buildStart = text.indexOf('Widget build(');
      expect(buildStart, greaterThanOrEqualTo(0));

      if (buildStart >= 0) {
        final String buildBody = text.substring(buildStart);
        expect(buildBody.contains('http.'), isFalse);
        expect(buildBody.contains('dio.'), isFalse);
      }
    });
  });
}
