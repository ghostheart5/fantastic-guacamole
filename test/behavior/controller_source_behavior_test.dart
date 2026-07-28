import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '_support/source_test_utils.dart';

void main() {
  group('Controller source behavior', () {
    test('controllers expose action methods and are not empty shells', () {
      final List<String> offenders = <String>[];

      const List<String> actionTokens = <String>[
        'load',
        'save',
        'start',
        'stop',
        'reset',
        'create',
        'update',
        'delete',
        'sign',
        'restore',
        'skip',
        'complete',
        'detect',
        'query',
        'to',
        'show(',
      ];

      for (final File file in SourceTestUtils.dartFilesUnder('lib')) {
        final String path = SourceTestUtils.normalizePath(file.path).toLowerCase();
        if (!path.contains('controller')) {
          continue;
        }
        if (path.endsWith('.g.dart') ||
            path.endsWith('.freezed.dart') ||
            path.endsWith('.providers.dart')) {
          continue;
        }

        final String text = SourceTestUtils.readText(file);
        final String lower = text.toLowerCase();

        final bool hasAction = actionTokens.any(lower.contains);
        final bool emptyClass = RegExp(r'class\s+\w+\s*\{\s*\}').hasMatch(text);

        if (!hasAction || emptyClass) {
          offenders.add(SourceTestUtils.normalizePath(file.path));
        }
      }

      expect(offenders, isEmpty, reason: 'Controllers missing real behavior: $offenders');
    });

    test('controllers avoid importing UI screens/widgets directly', () {
      final List<String> offenders = <String>[];

      for (final File file in SourceTestUtils.dartFilesUnder('lib')) {
        final String path = SourceTestUtils.normalizePath(file.path).toLowerCase();
        if (!path.contains('controller')) {
          continue;
        }
        if (path.endsWith('.g.dart') ||
            path.endsWith('.freezed.dart') ||
            path.endsWith('.providers.dart')) {
          continue;
        }

        final String text = SourceTestUtils.readText(file).toLowerCase();
        if (text.contains('/screen') || text.contains('/widget') || text.contains('/page')) {
          offenders.add(SourceTestUtils.normalizePath(file.path));
        }
      }

      expect(offenders, isEmpty, reason: 'Controllers should not couple to UI layer: $offenders');
    });

    test('controller filenames align with declared class/controller identifiers', () {
      final List<String> offenders = <String>[];

      for (final File file in SourceTestUtils.dartFilesUnder('lib')) {
        final String path = SourceTestUtils.normalizePath(file.path);
        final String lower = path.toLowerCase();
        if (!lower.contains('controller')) {
          continue;
        }
        if (lower.endsWith('.g.dart') ||
            lower.endsWith('.freezed.dart') ||
            lower.endsWith('.providers.dart')) {
          continue;
        }

        final String basename = path.split('/').last.replaceAll('.dart', '');
        final String text = SourceTestUtils.readText(file).toLowerCase();
        final String stem = basename.replaceAll('_controller', '').replaceAll('.providers', '');
        final bool hasClassOrControllerName =
            text.contains('class ') || text.contains('controller');
        if (stem.isNotEmpty && !text.contains(stem) && !hasClassOrControllerName) {
          offenders.add(path);
        }
      }

      expect(offenders, isEmpty, reason: 'Controller naming drift detected: $offenders');
    });
  });
}
