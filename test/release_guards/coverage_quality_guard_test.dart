import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('coverage quality guard', () {
    test('test suite quality checks pass for files under test/', () {
      final Directory testRoot = Directory('test');
      expect(testRoot.existsSync(), isTrue);

      final List<File> testFiles = testRoot
          .listSync(recursive: true)
          .whereType<File>()
          .where((File file) => file.path.endsWith('_test.dart'))
          .toList(growable: false);

      final List<String> issues = <String>[];
      final RegExp emptyExpectPattern = RegExp(
        r'expect\s*\(\s*true\s*,\s*true\s*\)\s*;',
        caseSensitive: false,
      );
      final RegExp todoPattern = RegExp(
        r'TODO:\s*add\s*test',
        caseSensitive: false,
      );
      final RegExp coverageOnlyPattern = RegExp(
        r'coverage\s+only',
        caseSensitive: false,
      );
      final RegExp skipTruePattern = RegExp(
        r'skip\s*:\s*true',
        caseSensitive: false,
      );
      final RegExp skipEmptyReasonPattern = RegExp(
        r'''skip\s*:\s*['"]\s*['"]''',
        caseSensitive: false,
      );

      for (final File file in testFiles) {
        final String normalized = file.path.replaceAll('\\', '/');
        final String content = file.readAsStringSync();
        final String trimmed = content.trim();

        if (trimmed.isEmpty) {
          issues.add('$normalized is empty.');
        }

        if (normalized.endsWith('_placeholder_test.dart')) {
          issues.add('$normalized uses placeholder file naming.');
        }

        if (emptyExpectPattern.hasMatch(content)) {
          issues.add('$normalized contains expect(true, true).');
        }

        if (todoPattern.hasMatch(content)) {
          issues.add('$normalized contains TODO add test marker.');
        }

        if (coverageOnlyPattern.hasMatch(content)) {
          issues.add('$normalized contains coverage-only wording.');
        }

        if (skipTruePattern.hasMatch(content) ||
            skipEmptyReasonPattern.hasMatch(content)) {
          issues.add(
            '$normalized has skipped tests without an explicit reason string.',
          );
        }

        final bool pumpsWidget = content.contains('pumpWidget(');
        final bool hasExpectation =
            content.contains('expect(') || content.contains('expectLater(');
        if (pumpsWidget && !hasExpectation) {
          issues.add('$normalized pumps widgets without assertions.');
        }

        final bool referencesLib =
            content.contains('package:fantastic_guacamole/') ||
            content.contains("import '../") ||
            content.contains('import "../');
        final bool requiresLibReference = normalized.contains(
          'test/coverage_expansion/',
        );

        if (requiresLibReference && !referencesLib) {
          issues.add('$normalized does not reference application lib code.');
        }
      }

      expect(issues, isEmpty, reason: issues.join('\n'));
    });
  });
}
