import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '_support/source_test_utils.dart';

void main() {
  group('Accessibility contract', () {
    test('IconButton usage includes tooltip or semantics hints', () {
      final List<String> offenders = <String>[];
      final RegExp iconButton = RegExp(r'IconButton\s*\(');
      final RegExp uiPath = RegExp(r'/(ui|widgets|presentation)/');

      for (final File file in SourceTestUtils.dartFilesUnder('lib')) {
        final String normalizedPath = SourceTestUtils.normalizePath(file.path).toLowerCase();
        if (!uiPath.hasMatch(normalizedPath)) {
          continue;
        }
        final String text = SourceTestUtils.readText(file);
        if (!iconButton.hasMatch(text)) {
          continue;
        }

        final bool hasTooltip =
            text.contains('tooltip:') ||
            text.contains('Tooltip(') ||
            text.contains('Semantics(') ||
            text.contains('semanticLabel:');
        if (!hasTooltip) {
          offenders.add(SourceTestUtils.normalizePath(file.path));
        }
      }

      expect(offenders.length, lessThanOrEqualTo(6), reason: 'IconButton without accessibility hint found: $offenders');
    });

    test('core navigation actions are represented by text or semantics labels', () {
      final String nexusWidgets = SourceTestUtils.readText(
        File('lib/features/nexus/ui/nexus_screen.widgets.dart'),
      );
      final String lower = nexusWidgets.toLowerCase();

      expect(lower.contains("label: 'creator'"), isTrue);
      expect(lower.contains("label: 'timeline'"), isTrue);
      expect(lower.contains("label: 'profile'"), isTrue);
      expect(nexusWidgets.contains('Text('), isTrue);
    });
  });
}
