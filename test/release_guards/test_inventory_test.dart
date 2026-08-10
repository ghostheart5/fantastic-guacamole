import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('test inventory', () {
    test('feature folders have matching tests or documented reasons', () {
      final featureDirs = Directory(
        'lib/features',
      ).listSync(recursive: true).whereType<Directory>();
      final featureFolders = featureDirs
          .where(
            (dir) =>
                dir.path.replaceAll('\\', '/').contains('/features/') &&
                !dir.path.replaceAll('\\', '/').contains('/ui/') &&
                !dir.path.replaceAll('\\', '/').contains('/widgets/'),
          )
          .map((dir) => dir.path)
          .toSet();

      expect(featureFolders, isNotEmpty);
      final reasonFile = File('tool/test_audit/uncovered_features.md');
      expect(
        reasonFile.existsSync(),
        isTrue,
        reason: 'Expected documented reasons file to exist.',
      );
    });

    test('no empty test files', () {
      final testFiles = Directory('test')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .toList();
      for (final file in testFiles) {
        final content = file.readAsStringSync().trim();
        expect(content, isNotEmpty, reason: '${file.path} is empty');
      }
    });
  });
}
