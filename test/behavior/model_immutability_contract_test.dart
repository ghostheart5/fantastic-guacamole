import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '_support/source_test_utils.dart';

void main() {
  group('Model immutability contract', () {
    test('model files prefer final fields and avoid UI imports', () {
      final List<String> offenders = <String>[];

      for (final File file in SourceTestUtils.dartFilesUnder('lib')) {
        final String path = SourceTestUtils.normalizePath(
          file.path,
        ).toLowerCase();
        if (!path.contains('model') && !path.contains('/entities/')) {
          continue;
        }

        final String text = SourceTestUtils.readText(file);
        final bool isBarrel =
            path.endsWith('/models.dart') || path.endsWith('/entities.dart');
        final bool isEnumOnly =
            RegExp(r'^\s*enum\s+\w+', multiLine: true).hasMatch(text) &&
            !RegExp(r'\bclass\s+\w+').hasMatch(text);
        if (isBarrel || isEnumOnly) {
          continue;
        }
        final bool hasField =
            RegExp(r'\n\s*(?:final|late\s+final|const)\s+').hasMatch(text) ||
            RegExp(r'\bclass\s+\w+').hasMatch(text);
        final bool importsUi =
            text.contains('package:flutter/material.dart') ||
            text.contains('package:flutter/widgets.dart');

        if (!hasField || importsUi) {
          offenders.add(SourceTestUtils.normalizePath(file.path));
        }
      }

      expect(
        offenders,
        isEmpty,
        reason: 'Model immutability or UI-boundary issues: $offenders',
      );
    });

    test(
      'copyWith and equality/hashCode implementations are paired when present',
      () {
        final List<String> offenders = <String>[];

        for (final File file in SourceTestUtils.dartFilesUnder('lib')) {
          final String path = SourceTestUtils.normalizePath(
            file.path,
          ).toLowerCase();
          if (!path.contains('model') && !path.contains('/entities/')) {
            continue;
          }

          final String text = SourceTestUtils.readText(file);
          final bool hasCopyWith = text.contains('copyWith(');
          final bool hasEq = text.contains('operator ==');
          final bool hasHash = text.contains('hashCode');

          if (hasCopyWith && (hasEq != hasHash)) {
            offenders.add(SourceTestUtils.normalizePath(file.path));
          }
        }

        expect(
          offenders,
          isEmpty,
          reason: 'Model equality/hashCode pairing issues: $offenders',
        );
      },
    );
  });
}
