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

  group('Source corruption guard', () {
    test(
      'lib Dart files do not contain replacement characters or common mojibake',
      () {
        final offenders = <String>[];

        final badTokens = <String>[
          '�',
          'Ã',
          'Â',
          'â€™',
          'â€œ',
          'â€',
          'ðŸ',
          'Ø',
          '¤',
        ];

        for (final file in dartFilesUnder('lib')) {
          final text = file.readAsStringSync();

          final found = badTokens.where(text.contains).toList();

          if (found.isNotEmpty) {
            offenders.add('${file.path}: $found');
          }
        }

        expect(
          offenders,
          isEmpty,
          reason: 'Possible encoding corruption/mojibake found: $offenders',
        );
      },
    );

    test('lib does not contain backup or generated repair drift files', () {
      final offenders = <String>[];
      final allowedCopyLikeFiles = <String>{
        'lib/features/si_console/ui/models/si_console_prompt_copy.dart',
      };

      final badNamePattern = RegExp(
        r'(\.bak($|\.)|_bak\.|_copy\.| copy\.|\.old\.|\.corrupt\.|fixed_fixed\.dart$)',
      );

      for (final file in dartFilesUnder('lib')) {
        final lower = file.path.toLowerCase();

        if (allowedCopyLikeFiles.contains(lower.replaceAll('\\', '/'))) {
          continue;
        }

        if (badNamePattern.hasMatch(lower)) {
          offenders.add(file.path);
        }
      }

      expect(
        offenders,
        isEmpty,
        reason: 'Backup/repair drift files found inside lib: $offenders',
      );
    });

    test('lib Dart files do not contain obvious merge conflict markers', () {
      final offenders = <String>[];

      for (final file in dartFilesUnder('lib')) {
        final text = file.readAsStringSync();

        if (text.contains('<<<<<<<') ||
            text.contains('=======') ||
            text.contains('>>>>>>>')) {
          offenders.add(file.path);
        }
      }

      expect(
        offenders,
        isEmpty,
        reason: 'Merge conflict markers found in lib: $offenders',
      );
    });
  });
}
