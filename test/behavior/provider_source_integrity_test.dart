import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '_support/source_test_utils.dart';

void main() {
  bool isProviderFile(String normalizedPath) {
    final String lower = normalizedPath.toLowerCase();
    if (!lower.endsWith('.dart')) {
      return false;
    }
    if (lower.endsWith('.g.dart') || lower.endsWith('.freezed.dart')) {
      return false;
    }
    if (lower.endsWith('/providers/providers.dart') ||
        lower.endsWith('/providers/monetization_guards.dart')) {
      return false;
    }
    final bool inProviderFolder = lower.contains('/providers/');
    final bool namedProviderFile =
        lower.endsWith('_provider.dart') || lower.endsWith('providers.dart');
    return inProviderFolder || namedProviderFile;
  }

  group('Provider source integrity', () {
    test('provider files declare concrete Provider types', () {
      final List<String> missing = <String>[];
      final RegExp providerDecl = RegExp(
        r'\b(Provider|StateProvider|NotifierProvider|AsyncNotifierProvider|FutureProvider|StreamProvider|StateNotifierProvider|ChangeNotifierProvider)<',
      );

      for (final File file in SourceTestUtils.dartFilesUnder('lib')) {
        final String path = SourceTestUtils.normalizePath(file.path);
        if (!isProviderFile(path)) {
          continue;
        }
        final String text = SourceTestUtils.readText(file);
        if (!providerDecl.hasMatch(text)) {
          missing.add(SourceTestUtils.normalizePath(file.path));
        }
      }

      expect(
        missing,
        isEmpty,
        reason: 'Provider-like files without provider declarations: $missing',
      );
    });

    test('provider files do not contain placeholder providers', () {
      final List<String> offenders = <String>[];
      const List<String> badTokens = <String>[
        'placeholder provider',
        'no operation provider',
      ];

      for (final File file in SourceTestUtils.dartFilesUnder('lib')) {
        final String path = SourceTestUtils.normalizePath(file.path);
        if (!isProviderFile(path)) {
          continue;
        }
        final String text = SourceTestUtils.readText(file).toLowerCase();
        if (badTokens.any(text.contains)) {
          offenders.add(SourceTestUtils.normalizePath(file.path));
        }
      }

      expect(
        offenders,
        isEmpty,
        reason: 'Provider files contain placeholder markers: $offenders',
      );
    });

    test('provider files avoid importing screens directly', () {
      final List<String> offenders = <String>[];
      final RegExp importLine = RegExp(r"import\s+'([^']+)';");

      for (final File file in SourceTestUtils.dartFilesUnder('lib')) {
        final String path = SourceTestUtils.normalizePath(file.path);
        if (!isProviderFile(path)) {
          continue;
        }
        final String text = SourceTestUtils.readText(file);
        final List<String> imports = SourceTestUtils.regexStrings(
          text,
          importLine,
          1,
        );
        final bool importsUi = imports.any((String value) {
          final String l = value.toLowerCase();
          return l.contains('/screen') ||
              l.contains('/page') ||
              l.contains('/widget');
        });
        if (importsUi) {
          offenders.add(SourceTestUtils.normalizePath(file.path));
        }
      }

      expect(
        offenders,
        isEmpty,
        reason: 'Provider files should not import UI directly: $offenders',
      );
    });

    test('duplicate provider variable names are detected', () {
      final List<String> duplicates = <String>[];
      final RegExp providerName = RegExp(r'final\s+([a-zA-Z_]\w*Provider)\s*=');

      for (final File file in SourceTestUtils.dartFilesUnder('lib')) {
        final String path = SourceTestUtils.normalizePath(file.path);
        if (!isProviderFile(path)) {
          continue;
        }
        final String text = SourceTestUtils.readText(file);
        final Set<String> seenInFile = <String>{};
        for (final Match match in providerName.allMatches(text)) {
          final String name = match.group(1)!;
          if (!seenInFile.add(name)) {
            duplicates.add('$name: $path');
          }
        }
      }

      expect(
        duplicates,
        isEmpty,
        reason: 'Duplicate provider names detected: $duplicates',
      );
    });
  });
}
