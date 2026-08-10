import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '_support/source_test_utils.dart';

void main() {
  group('Navigation runtime contract', () {
    test(
      'lib does not use BottomNavigationBar, NavigationBar, or NavigationDestination',
      () {
        final List<String> offenders = <String>[];

        for (final File file in SourceTestUtils.dartFilesUnder('lib')) {
          final String path = SourceTestUtils.normalizePath(
            file.path,
          ).toLowerCase();
          if (path.endsWith('/theme/app_theme.dart')) {
            continue;
          }
          final String text = SourceTestUtils.readText(file);
          if (text.contains('BottomNavigationBar') ||
              text.contains('NavigationBar(') ||
              text.contains('NavigationDestination(')) {
            offenders.add(SourceTestUtils.normalizePath(file.path));
          }
        }

        expect(
          offenders,
          isEmpty,
          reason:
              'Bottom navigation widgets are not allowed by architecture: $offenders',
        );
      },
    );

    test('route constants include core ChronoSpark destinations', () {
      final File routes = File('lib/app/router/route_paths.dart');
      final String text = SourceTestUtils.readText(routes);

      const List<String> required = <String>[
        'home',
        'creator',
        'timeline',
        'profile',
        'progression',
        'si',
        'settings',
      ];

      for (final String route in required) {
        expect(text.contains('static const $route'), isTrue);
      }
    });

    test('creator and timeline route semantics are preserved', () {
      final String routes = SourceTestUtils.readText(
        File('lib/app/router/route_paths.dart'),
      );
      expect(routes.contains("static const creator = '/creator';"), isTrue);
      expect(
        routes.contains("static const timeline = '/settings/advanced/logs';"),
        isTrue,
      );
    });

    test('internal engines are not top-level route constants', () {
      final String routes = SourceTestUtils.readText(
        File('lib/app/router/route_paths.dart'),
      );
      expect(routes.contains('static const memories'), isFalse);
      expect(routes.contains('static const insights ='), isTrue);
      expect(routes.contains('static const flowmap'), isFalse);
    });
  });
}
