import 'dart:io';

import 'package:fantastic_guacamole/features/si_console/ui/si_console_screen.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '_support/source_test_utils.dart';

void main() {
  group('SI Console contract', () {
    test('SI Console screen is importable and present', () {
      const Widget widget = SIConsoleScreen();
      expect(widget, isA<SIConsoleScreen>());
      expect(
        File('lib/features/si_console/ui/si_console_screen.dart').existsSync(),
        isTrue,
      );
    });

    test(
      'SI Console source does not contain hard-coded Supabase keys or bearer tokens',
      () {
        final String text = SourceTestUtils.readText(
          File('lib/features/si_console/ui/si_console_screen.dart'),
        );
        final String lower = text.toLowerCase();

        expect(lower.contains('service_role'), isFalse);
        expect(lower.contains('bearer '), isFalse);
        expect(
          lower.contains('supabase.co') && lower.contains('anon'),
          isFalse,
        );
      },
    );

    test('SI Console uses service/provider boundaries for data access', () {
      final String text = SourceTestUtils.readText(
        File('lib/features/si_console/ui/si_console_screen.dart'),
      ).toLowerCase();

      expect(text.contains('provider') || text.contains('service'), isTrue);
      expect(text.contains('api_key='), isFalse);
    });
  });
}
