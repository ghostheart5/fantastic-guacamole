import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '_support/source_test_utils.dart';

void main() {
  group('Test secret hygiene', () {
    test('test code does not contain real secrets or keys', () {
      final List<String> offenders = <String>[];
      final _SecretAllowlist allowlist = _SecretAllowlist.load(
        '_support/test_secret_hygiene_allowlist.txt',
      );

      final RegExp secretPattern = RegExp(
        r'''(service[_-]?role[_-]?key\s*[:=]\s*['"][^'"]+['"]|sb_secret_[A-Za-z0-9]{16,}|-----BEGIN PRIVATE KEY-----|github_pat_[A-Za-z0-9_]{20,}|ghp_[A-Za-z0-9]{20,}|ghs_[A-Za-z0-9]{20,}|AIza[0-9A-Za-z\-_]{35})''',
        caseSensitive: false,
      );

      final List<File> files =
          <File>[
                ...SourceTestUtils.filesUnder('test'),
                ...SourceTestUtils.filesUnder('integration_test'),
              ]
              .where((File file) {
                final String path = SourceTestUtils.normalizePath(
                  file.path,
                ).toLowerCase();
                return path.endsWith('.dart') ||
                    path.endsWith('.yml') ||
                    path.endsWith('.yaml') ||
                    path.endsWith('.json') ||
                    path.endsWith('.md');
              })
              .toList(growable: false);

      for (final File file in files) {
        final String path = SourceTestUtils.normalizePath(file.path);
        final String text = SourceTestUtils.readText(file);

        final String lowerPath = path.toLowerCase();
        if (allowlist.isPathAllowed(lowerPath)) {
          continue;
        }

        final Iterable<RegExpMatch> matches = secretPattern.allMatches(text);
        for (final RegExpMatch match in matches) {
          final int start = match.start;
          final int end = match.end;
          final int contextStart = start - 80 < 0 ? 0 : start - 80;
          final int contextEnd = end + 80 > text.length
              ? text.length
              : end + 80;
          final String context = text
              .substring(contextStart, contextEnd)
              .toLowerCase();

          final bool looksLikeIntentionalPlaceholder = allowlist
              .isContextAllowed(context);

          if (!looksLikeIntentionalPlaceholder) {
            offenders.add(path);
            break;
          }
        }
      }

      expect(
        offenders,
        isEmpty,
        reason: 'Potential secret/key leakage in tests: $offenders',
      );
    });
  });
}

class _SecretAllowlist {
  _SecretAllowlist({
    required this.allowedPathSuffixes,
    required this.allowedContextMarkers,
  });

  final List<String> allowedPathSuffixes;
  final List<String> allowedContextMarkers;

  bool isPathAllowed(String lowerPath) {
    for (final String suffix in allowedPathSuffixes) {
      if (lowerPath.endsWith(suffix)) {
        return true;
      }
    }
    return false;
  }

  bool isContextAllowed(String lowerContext) {
    for (final String marker in allowedContextMarkers) {
      if (lowerContext.contains(marker)) {
        return true;
      }
    }
    return false;
  }

  static _SecretAllowlist load(String relativePath) {
    final File file = File('test/behavior/$relativePath');
    if (!file.existsSync()) {
      return _SecretAllowlist(
        allowedPathSuffixes: const <String>[],
        allowedContextMarkers: const <String>[],
      );
    }

    final List<String> pathSuffixes = <String>[];
    final List<String> contextMarkers = <String>[];

    final List<String> lines = file.readAsLinesSync();
    for (final String raw in lines) {
      final String line = raw.trim();
      if (line.isEmpty || line.startsWith('#')) {
        continue;
      }
      if (line.startsWith('path:')) {
        pathSuffixes.add(line.substring('path:'.length).trim().toLowerCase());
      } else if (line.startsWith('context:')) {
        contextMarkers.add(
          line.substring('context:'.length).trim().toLowerCase(),
        );
      }
    }

    return _SecretAllowlist(
      allowedPathSuffixes: pathSuffixes,
      allowedContextMarkers: contextMarkers,
    );
  }
}
