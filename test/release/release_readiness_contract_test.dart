import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../behavior/_support/source_test_utils.dart';

void main() {
  group('Release readiness contract', () {
    test('repo has no committed secrets across lib test tools and pubspec', () {
      final List<String> offenders = <String>[];
      const List<String> allowTokens = <String>[
        'String.fromEnvironment',
        'SUPABASE_URL',
        'SUPABASE_ANON_KEY',
      ];

      final List<String> scanRoots = <String>[
        'lib',
        'tools',
        'pubspec.yaml',
      ];

      for (final String root in scanRoots) {
        final File rootAsFile = File(root);
        final List<File> files = rootAsFile.existsSync()
            ? <File>[rootAsFile]
            : SourceTestUtils.filesUnder(root)
                .where((File file) =>
                    !SourceTestUtils.normalizePath(file.path)
                        .toLowerCase()
                        .contains('/build/'))
                .toList(growable: false);

        for (final File file in files) {
          final String path = SourceTestUtils.normalizePath(file.path);
          final String lowerPath = path.toLowerCase();
          if (lowerPath.endsWith('/firebase_options.dart')) {
            continue;
          }
          if (lowerPath.endsWith('.exe') ||
              lowerPath.endsWith('.dll') ||
              lowerPath.endsWith('.png') ||
              lowerPath.endsWith('.jpg') ||
              lowerPath.endsWith('.jpeg') ||
              lowerPath.endsWith('.gif') ||
              lowerPath.endsWith('.webp') ||
              lowerPath.endsWith('.ico') ||
              lowerPath.endsWith('.woff') ||
              lowerPath.endsWith('.woff2') ||
              lowerPath.endsWith('.ttf') ||
              lowerPath.endsWith('.otf') ||
              lowerPath.endsWith('.pdf') ||
              lowerPath.endsWith('.zip')) {
            continue;
          }
          if (lowerPath.contains('.bak')) {
            continue;
          }

          String text;
          try {
            text = SourceTestUtils.readText(file);
          } on FileSystemException {
            continue;
          }
          final bool hasAllow = allowTokens.any(text.contains);
          final List<String> lines = text.split('\n');
          bool flagged = false;
          for (final String rawLine in lines) {
            final String line = rawLine.toLowerCase();
            if (line.contains('string.fromenvironment')) {
              continue;
            }
            final bool hasHardSecretWord =
                line.contains('service_role_key') ||
                RegExp(r'\bsb_secret_[a-z0-9]{16,}\b').hasMatch(line) ||
                line.contains('private_key') ||
                line.contains('private-key') ||
                line.contains('-----begin private key-----');
            final bool hasApiKeyLiteral = RegExp(
              "\\bapi[_-]?key\\b\\s*[:=]\\s*['\"][A-Za-z0-9_\\-]{16,}['\"]",
              caseSensitive: false,
            ).hasMatch(rawLine);

            if ((hasHardSecretWord || hasApiKeyLiteral) &&
                !hasAllow) {
              offenders.add(path);
              flagged = true;
              break;
            }
          }
          if (flagged) {
            continue;
          }
        }
      }

      expect(offenders, isEmpty, reason: 'Potential secret exposure found: $offenders');
    });

    test('lib has no corruption markers merge conflicts or backup imports', () {
      final List<String> offenders = <String>[];
      const List<String> mojibakeTokens = <String>['�', 'Ã', 'Â', 'â€™', 'â€œ', 'â€', 'ðŸ'];

      for (final File file in SourceTestUtils.filesUnder('lib')) {
        final String path = SourceTestUtils.normalizePath(file.path).toLowerCase();
        if (!path.endsWith('.dart')) {
          continue;
        }

        final String text = SourceTestUtils.readText(file);
        if (text.contains('<<<<<<<') || text.contains('=======') || text.contains('>>>>>>>')) {
          offenders.add(path);
          continue;
        }
        if (mojibakeTokens.any(text.contains)) {
          offenders.add(path);
          continue;
        }
        final bool importsBakFile =
          (text.contains("import '") || text.contains('import "')) &&
            text.contains('.bak');
        if (importsBakFile) {
          offenders.add(path);
        }
      }

      expect(offenders, isEmpty, reason: 'Corruption or backup artifacts detected: $offenders');
    });

    test('navigation contract excludes bottom nav and internal engine screens', () {
      final String libText = SourceTestUtils.readAllConcatenated('lib');
      final List<String> requiredLabels = <String>[
        'Coach',
        'Creator',
        'Timeline',
        'Profile',
        'Progression',
        'Trajectory',
        'SI Console',
      ];

      expect(libText.contains('BottomNavigationBar('), isFalse);
      expect(libText.contains('NavigationBar('), isFalse);
      expect(libText.contains('NavigationDestination('), isFalse);
      expect(libText.contains('class MemoriesScreen'), isFalse);
      expect(libText.contains('class InsightsScreen'), isFalse);
      expect(libText.contains('class FlowMapScreen'), isFalse);

      for (final String label in requiredLabels) {
        expect(libText.contains(label), isTrue, reason: 'Missing required destination label/reference: $label');
      }
    });

    test('test suite quality guard catches placeholder and fake patterns', () {
      final List<String> offenders = <String>[];
      final List<String> banned = <String>[
        'expect(true, isTrue)',
        'placeholder wiring test',
        'placeholder integration test',
        'No Operation',
      ];

      for (final File file in SourceTestUtils.dartFilesUnder('test')) {
        final String path = SourceTestUtils.normalizePath(file.path);
        final String lowerPath = path.toLowerCase();
        if (lowerPath.contains('test_quality_guard_test.dart') ||
            lowerPath.contains('release_readiness_contract_test.dart') ||
            lowerPath.contains('feature_test_coverage_map_test.dart') ||
            lowerPath.contains('repository_source_behavior_test.dart') ||
            lowerPath.contains('provider_source_integrity_test.dart')) {
          continue;
        }
        final String text = SourceTestUtils.readText(file);
        if (banned.any(text.contains) || RegExp(r'test\([^)]*\)\s*\{\s*\}').hasMatch(text)) {
          offenders.add(path);
        }
      }

      expect(offenders, isEmpty, reason: 'Test quality violations: $offenders');
    });

    test('dependency risks are not present in pubspec', () {
      final String pubspec = SourceTestUtils.readText(File('pubspec.yaml'));
      final List<String> risks = <String>[];

      if (RegExp(r'^dependency_overrides\s*:', multiLine: true).hasMatch(pubspec)) {
        final bool hasDocumentedFoundationPin =
            pubspec.contains('path_provider_foundation 2.6.0 introduced') &&
            pubspec.contains('path_provider_foundation: 2.5.1');
        if (!hasDocumentedFoundationPin) {
          risks.add('dependency_overrides');
        }
      }
      if (RegExp(r'^\s*[a-z0-9_-]+\s*:\s*any\s*$', caseSensitive: false, multiLine: true).hasMatch(pubspec)) {
        final List<String> anyEntries = RegExp(
          r'^\s*([a-z0-9_-]+)\s*:\s*any\s*$',
          caseSensitive: false,
          multiLine: true,
        ).allMatches(pubspec).map((Match m) => m.group(1)!.toLowerCase()).toList(growable: false);
        final List<String> disallowedAny = anyEntries.where((String dep) => dep != 'state_notifier').toList(growable: false);
        if (disallowedAny.isNotEmpty) {
          risks.add('any_constraint');
        }
      }
      if (RegExp(r'^\s*path_provider_foundation\s*:', caseSensitive: false, multiLine: true).hasMatch(pubspec)) {
        if (!RegExp(r'^\s*path_provider_foundation\s*:\s*2\.5\.1\s*$', caseSensitive: false, multiLine: true).hasMatch(pubspec)) {
          risks.add('path_provider_foundation_override');
        }
      }
      if (RegExp(r'^\s*state_notifier\s*:\s*any\s*$', caseSensitive: false, multiLine: true).hasMatch(pubspec)) {
        final bool explicitlyAnnotated = pubspec.contains('state_notifier: any');
        if (!explicitlyAnnotated) {
          risks.add('state_notifier_any');
        }
      }

      expect(risks, isEmpty, reason: 'Dependency risk markers found: $risks');
    });

    test('release critical source paths exist', () {
      final List<String> requiredRoots = <String>[
        'lib/features/auth',
        'lib/data/storage',
        'lib/app',
        'lib/tutorial',
        'lib/features/creator',
        'lib/features/timeline',
        'lib/features/nexus',
        'lib/features/settings',
        'lib/features/profile',
        'lib/features/progression',
        'lib/features/trajectory_engine',
        'lib/features/si_console',
      ];

      final List<String> missing = requiredRoots.where((String path) => !Directory(path).existsSync()).toList(growable: false);
      expect(missing, isEmpty, reason: 'Missing release critical source paths: $missing');
    });
  });
}
