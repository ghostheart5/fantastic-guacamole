import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '_support/source_test_utils.dart';

void main() {
  group('Route name contract', () {
    test('route constants are not duplicated with inconsistent values', () {
      final File routesFile = File('lib/app/router/route_paths.dart');
      final String text = SourceTestUtils.readText(routesFile);

      final RegExp pattern = RegExp(
        "static const\\s+(\\w+)\\s*=\\s*'([^']+)';",
      );
      final Map<String, String> values = <String, String>{};
      final List<String> duplicates = <String>[];

      for (final Match match in pattern.allMatches(text)) {
        final String name = match.group(1)!;
        final String value = match.group(2)!;
        if (values.containsKey(name) && values[name] != value) {
          duplicates.add('$name => ${values[name]} vs $value');
        } else {
          values[name] = value;
        }
      }

      expect(
        duplicates,
        isEmpty,
        reason: 'Inconsistent route constants found: $duplicates',
      );
    });

    test('required core route identifiers exist', () {
      final String routes = SourceTestUtils.readText(
        File('lib/app/router/route_paths.dart'),
      );
      const List<String> required = <String>[
        'home',
        'creator',
        'timeline',
        'profile',
        'progression',
        'si',
      ];
      for (final String key in required) {
        expect(routes.contains('static const $key'), isTrue);
      }
    });

    test(
      'stale internal-engine routes are not exposed as top-level constants',
      () {
        final String routes = SourceTestUtils.readText(
          File('lib/app/router/route_paths.dart'),
        ).toLowerCase();
        expect(routes.contains('static const memories'), isFalse);
        expect(routes.contains('static const flowmap'), isFalse);
      },
    );
  });
}
