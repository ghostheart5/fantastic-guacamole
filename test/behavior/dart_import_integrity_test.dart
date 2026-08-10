import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  List<File> dartFilesUnder(String path) {
    final root = Directory(path);
    if (!root.existsSync()) return <File>[];

    return root
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .toList();
  }

  group('Dart import integrity', () {
    test('relative imports exports and parts point to existing files', () {
      final broken = <String>[];

      final statementPattern = RegExp(
        r'''(?:import|export|part)\s+['"]([^'"]+)['"]''',
      );

      for (final file in dartFilesUnder('lib')) {
        final text = file.readAsStringSync();

        for (final match in statementPattern.allMatches(text)) {
          final uri = match.group(1)!;

          if (uri.startsWith('dart:')) continue;
          if (uri.startsWith('package:')) continue;

          final resolved = File.fromUri(file.parent.uri.resolve(uri));

          if (!resolved.existsSync()) {
            broken.add('${file.path} -> $uri');
          }
        }
      }

      expect(
        broken,
        isEmpty,
        reason: 'Broken relative Dart imports/exports/parts found: $broken',
      );
    });

    test('lib does not import files from test folder', () {
      final offenders = <String>[];

      for (final file in dartFilesUnder('lib')) {
        final text = file.readAsStringSync();

        if (text.contains("import '../test") ||
            text.contains('import "../test') ||
            text.contains("import '../../test") ||
            text.contains('import "../../test') ||
            text.contains('package:flutter_test')) {
          offenders.add(file.path);
        }
      }

      expect(
        offenders,
        isEmpty,
        reason:
            'Production lib code must not import test-only code: $offenders',
      );
    });
  });
}
