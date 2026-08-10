import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../behavior/_support/source_test_utils.dart';

void main() {
  group('Route name release contract', () {
    test(
      'route path constants include core destinations and avoid internal screen drift',
      () {
        final File file = File('lib/app/router/route_paths.dart');
        expect(file.existsSync(), isTrue);
        final String text = SourceTestUtils.readText(file);

        expect(text.contains('creator'), isTrue);
        expect(text.contains('timeline'), isTrue);
        expect(text.contains('profile'), isTrue);
        expect(text.contains('progression'), isTrue);
        expect(text.contains('si'), isTrue);

        expect(text.contains('MemoriesScreen'), isFalse);
        expect(text.contains('InsightsScreen'), isFalse);
        expect(text.contains('FlowMapScreen'), isFalse);
      },
    );

    test('route constant values are not duplicated inconsistently', () {
      final File file = File('lib/app/router/route_paths.dart');
      final String text = SourceTestUtils.readText(file);
      final Iterable<Match> matches = RegExp(
        r"static const [a-zA-Z0-9_]+ = '([^']+)';",
      ).allMatches(text);
      final Map<String, int> counts = <String, int>{};

      for (final Match match in matches) {
        final String? value = match.group(1);
        if (value == null) {
          continue;
        }
        counts[value] = (counts[value] ?? 0) + 1;
      }

      final List<String> suspicious = counts.entries
          .where((MapEntry<String, int> entry) => entry.value > 2)
          .map((MapEntry<String, int> entry) => '${entry.key}:${entry.value}')
          .toList(growable: false);

      expect(
        suspicious,
        isEmpty,
        reason: 'Suspiciously duplicated route constants: $suspicious',
      );
    });
  });
}
