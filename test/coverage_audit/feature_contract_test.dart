import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('user-facing feature contract', () {
    test('core user-facing feature folders exist', () {
      final expected = <String>[
        'lib/features/nexus',
        'lib/features/creator',
        'lib/features/timeline',
        'lib/features/profile',
        'lib/features/progression',
        'lib/features/si_console',
        'lib/features/home',
      ];

      for (final path in expected) {
        expect(Directory(path).existsSync(), isTrue, reason: path);
      }
    });

    test('internal engines are not exposed as standalone nav screens', () {
      final shell = File('lib/app/navigation_shell.dart');
      expect(shell.existsSync(), isTrue);

      final content = shell.readAsStringSync();

      expect(content.contains('MemoriesScreen'), isFalse);
      expect(content.contains('InsightsScreen'), isFalse);
      expect(content.contains('FlowMapScreen'), isFalse);
    });
  });
}
