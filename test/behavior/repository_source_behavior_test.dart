import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '_support/source_test_utils.dart';

void main() {
  bool isConcreteRepositoryPath(String path) {
    final String lower = path.toLowerCase();
    if (!lower.endsWith('.dart')) {
      return false;
    }
    if (lower.endsWith('.g.dart') || lower.endsWith('.freezed.dart')) {
      return false;
    }
    if (!lower.contains('repository')) {
      return false;
    }
    if (lower.contains('/domain/interfaces/')) {
      return false;
    }
    return lower.contains('/data/') || lower.contains('/repositories/');
  }

  group('Repository source behavior', () {
    test('repositories expose at least one data operation verb', () {
      final List<String> offenders = <String>[];
      final RegExp methodVerb = RegExp(
        r'\b(load|save|fetch|get|list|create|update|delete|remove|add|watch|stream|clear|reset|purchase|verify|sync)\w*\s*\(',
      );

      for (final File file in SourceTestUtils.dartFilesUnder('lib')) {
        final String normalizedPath = SourceTestUtils.normalizePath(file.path);
        if (!isConcreteRepositoryPath(normalizedPath)) {
          continue;
        }

        final String text = SourceTestUtils.readText(file);
        if (!methodVerb.hasMatch(text)) {
          offenders.add(SourceTestUtils.normalizePath(file.path));
        }
      }

      expect(
        offenders,
        isEmpty,
        reason: 'Repository files missing operation methods: $offenders',
      );
    });

    test('repositories do not import Flutter widget or material UI', () {
      final List<String> offenders = <String>[];

      for (final File file in SourceTestUtils.dartFilesUnder('lib')) {
        final String normalizedPath = SourceTestUtils.normalizePath(file.path);
        if (!isConcreteRepositoryPath(normalizedPath)) {
          continue;
        }

        final String text = SourceTestUtils.readText(file);
        if (text.contains("package:flutter/material.dart") ||
            text.contains("package:flutter/widgets.dart")) {
          offenders.add(SourceTestUtils.normalizePath(file.path));
        }
      }

      expect(
        offenders,
        isEmpty,
        reason: 'Repositories should not depend on UI widgets: $offenders',
      );
    });

    test(
      'repositories avoid direct screen/page/widget imports and placeholder bodies',
      () {
        final List<String> offenders = <String>[];
        final List<String> placeholders = <String>[
          'placeholder repository',
          'no operation repository',
        ];

        for (final File file in SourceTestUtils.dartFilesUnder('lib')) {
          final String normalizedPath = SourceTestUtils.normalizePath(
            file.path,
          );
          if (!isConcreteRepositoryPath(normalizedPath)) {
            continue;
          }

          final String text = SourceTestUtils.readText(file);
          final String lower = text.toLowerCase();
          final bool hasUiImport = RegExp(
            r'''import\s+['\"][^'\"]*(/ui/|/presentation/)[^'\"]*['\"]''',
          ).hasMatch(lower);
          final bool hasPlaceholder = placeholders.any(text.contains);
          final bool emptyClass = RegExp(
            r'class\s+\w+\s*\{\s*\}',
          ).hasMatch(text);

          if (hasUiImport || hasPlaceholder || emptyClass) {
            offenders.add(SourceTestUtils.normalizePath(file.path));
          }
        }

        expect(
          offenders,
          isEmpty,
          reason: 'Repository boundary or quality violations: $offenders',
        );
      },
    );
  });
}
