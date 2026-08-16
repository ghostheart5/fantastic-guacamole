import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '_support/source_test_utils.dart';

void main() {
  group('Test quality guard', () {
    test(
      'dart tests do not contain placeholder markers or empty test bodies',
      () {
        final List<String> offenders = <String>[];
        final List<String> bannedLiterals = <String>[
          'expect(true, isTrue)',
          'placeholder wiring test',
          'placeholder integration test',
          'No Operation',
        ];

        final List<RegExp> bannedPatterns = <RegExp>[
          RegExp(r'^\s*expect\(\s*true\s*,\s*isTrue\s*\)\s*;', multiLine: true),
          RegExp(r'^\s*test\([^)]*\)\s*\{\s*\}\s*$', multiLine: true),
        ];

        for (final File file in SourceTestUtils.dartFilesUnder('test')) {
          final String path = SourceTestUtils.normalizePath(file.path);
          if (!path.endsWith('_test.dart') ||
              path.contains('/robot/') ||
              path.contains('/helpers/') ||
              path.contains('/support/')) {
            continue;
          }
          final String lowerPath = path.toLowerCase();
          if (lowerPath.endsWith('/test_quality_guard_test.dart') ||
              lowerPath.endsWith('/release_readiness_contract_test.dart') ||
              lowerPath.endsWith('/feature_test_coverage_map_test.dart') ||
              lowerPath.endsWith('/provider_source_integrity_test.dart') ||
              lowerPath.endsWith('/repository_source_behavior_test.dart')) {
            continue;
          }

          final String text = SourceTestUtils.readText(file);
          final String lower = text.toLowerCase();

          final bool hasBannedLiteral = bannedLiterals.any(
            (String token) => lower.contains(token.toLowerCase()),
          );
          final bool hasBannedPattern = bannedPatterns.any(
            (RegExp pattern) => pattern.hasMatch(text),
          );
          if (hasBannedLiteral || hasBannedPattern) {
            offenders.add(path);
          }
        }

        expect(
          offenders,
          isEmpty,
          reason: 'Low-quality or placeholder tests found: $offenders',
        );
      },
    );

    test(
      'each dart test file contains a real assertion or widget verification path',
      () {
        final List<String> offenders = <String>[];
        const List<String> assertionTokens = <String>[
          'expect(',
          'throwsA(',
          'pumpWidget(',
          'takeException(',
          'defineFeatureUnitTests(',
          'defineFeatureIntegrationTests(',
        ];

        for (final File file in SourceTestUtils.dartFilesUnder('test')) {
          final String path = SourceTestUtils.normalizePath(file.path);
          if (!path.endsWith('_test.dart') ||
              path.contains('/robot/') ||
              path.contains('/helpers/') ||
              path.contains('/support/')) {
            continue;
          }

          if (path.contains('/_support/')) {
            continue;
          }

          if (path.endsWith('/flutter_test_config.dart')) {
            continue;
          }

          final String text = SourceTestUtils.readText(file);
          final bool hasAssertion = assertionTokens.any(text.contains);
          if (!hasAssertion) {
            offenders.add(path);
          }
        }

        expect(
          offenders,
          isEmpty,
          reason: 'Test files without concrete assertions: $offenders',
        );
      },
    );

    test('major UI surfaces have at least one golden visual test', () {
      final List<String> requiredUiFolders = <String>[
        'package:fantastic_guacamole/features/auth/ui/',
        'package:fantastic_guacamole/features/settings/ui/',
        'package:fantastic_guacamole/features/trajectory_engine/ui/',
        'package:fantastic_guacamole/ui/widgets/',
      ];

      final List<File> goldenTests =
          SourceTestUtils.dartFilesUnder('test/golden')
              .where((File file) => file.path.endsWith('_golden_test.dart'))
              .toList(growable: false);

      final String combinedGoldenSource = goldenTests
          .map(SourceTestUtils.readText)
          .join('\n');

      final List<String> missingFolders = <String>[];
      for (final String folder in requiredUiFolders) {
        if (!combinedGoldenSource.contains(folder)) {
          missingFolders.add(folder);
        }
      }

      expect(
        missingFolders,
        isEmpty,
        reason:
            'Missing golden visual tests for major UI folders: $missingFolders',
      );
    });
  });
}
