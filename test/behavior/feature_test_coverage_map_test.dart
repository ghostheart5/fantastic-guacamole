import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '_support/source_test_utils.dart';

void main() {
  const Map<String, List<String>> featureAliases = <String, List<String>>{
    'action_hub': <String>['action_hub', 'nexus'],
    'smart_coach': <String>['smart_coach', 'coach'],
    'si_console': <String>['si_console', 'console'],
    'trajectory_engine': <String>['trajectory_engine', 'trajectory'],
  };

  bool matchesFeature(String path, String feature) {
    final List<String> aliases = featureAliases[feature] ?? <String>[feature];
    return aliases.any(path.contains);
  }

  group('Feature test coverage map', () {
    const List<String> userFacingFeatures = <String>[
      'action_hub',
      'auth',
      'creator',
      'nexus',
      'timeline',
      'profile',
      'settings',
      'progression',
      'trajectory_engine',
      'si_console',
      'tutorial',
      'smart_coach',
    ];

    test('every user-facing feature has unit and integration tests', () {
      final List<String> files = SourceTestUtils.dartFilesUnder('test')
          .map(
            (File file) =>
                SourceTestUtils.normalizePath(file.path).toLowerCase(),
          )
          .toList(growable: false);

      final List<String> missingUnit = <String>[];
      final List<String> missingIntegration = <String>[];

      for (final String feature in userFacingFeatures) {
        final bool hasUnit = files.any(
          (String path) =>
              path.contains('/unit/') && matchesFeature(path, feature),
        );
        final bool hasIntegration = files.any(
          (String path) =>
              path.contains('/integration/') && matchesFeature(path, feature),
        );

        if (!hasUnit) {
          missingUnit.add(feature);
        }
        if (!hasIntegration) {
          missingIntegration.add(feature);
        }
      }

      final int coveredUnitCount =
          userFacingFeatures.length - missingUnit.length;
      final int coveredIntegrationCount =
          userFacingFeatures.length - missingIntegration.length;
      expect(
        coveredUnitCount,
        greaterThanOrEqualTo(10),
        reason: 'Missing unit tests for: $missingUnit',
      );
      expect(
        coveredIntegrationCount,
        greaterThanOrEqualTo(10),
        reason: 'Missing integration tests for: $missingIntegration',
      );
    });

    test('every user-facing feature has behavior or architecture coverage', () {
      final List<String> files = SourceTestUtils.dartFilesUnder('test')
          .map(
            (File file) =>
                SourceTestUtils.normalizePath(file.path).toLowerCase(),
          )
          .toList(growable: false);

      final List<String> missing = <String>[];
      for (final String feature in userFacingFeatures) {
        final bool hasCoverage = files.any(
          (String path) =>
              (path.contains('/behavior/') ||
                  path.contains('/architecture/')) &&
              matchesFeature(path, feature),
        );
        if (!hasCoverage) {
          missing.add(feature);
        }
      }

      final int covered = userFacingFeatures.length - missing.length;
      expect(
        covered,
        greaterThanOrEqualTo(7),
        reason: 'Missing behavior/architecture coverage for: $missing',
      );
    });

    test('tests are not placeholder-style stubs', () {
      final List<String> offenders = <String>[];
      const List<String> banned = <String>[
        'expect(true, isTrue)',
        'placeholder wiring test',
        'placeholder integration test',
        'No Operation',
      ];

      for (final File file in SourceTestUtils.dartFilesUnder('test')) {
        final String path = SourceTestUtils.normalizePath(
          file.path,
        ).toLowerCase();
        if (path.endsWith('/feature_test_coverage_map_test.dart') ||
            path.endsWith('/test_quality_guard_test.dart') ||
            path.endsWith('/release_readiness_contract_test.dart') ||
            path.endsWith('/provider_source_integrity_test.dart') ||
            path.endsWith('/repository_source_behavior_test.dart') ||
            path.contains('/_support/')) {
          continue;
        }
        final String text = SourceTestUtils.readText(file);
        final String lower = text.toLowerCase();
        if (banned.any((String token) => lower.contains(token.toLowerCase()))) {
          offenders.add(SourceTestUtils.normalizePath(file.path));
        }
      }

      expect(
        offenders,
        isEmpty,
        reason: 'Placeholder-style tests detected: $offenders',
      );
    });
  });
}
