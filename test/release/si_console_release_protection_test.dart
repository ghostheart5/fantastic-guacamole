import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../behavior/_support/source_test_utils.dart';

void main() {
  group('SI Console release protection', () {
    test('si console source exists and is represented as debug/ai interface', () {
      final File file = File('lib/features/si_console/ui/si_console_screen.dart');
      expect(file.existsSync(), isTrue);
      final String text = SourceTestUtils.readText(file).toLowerCase();

      expect(text.contains('strategic intelligence') || text.contains('si console'), isTrue);
      expect(text.contains('debug') || text.contains('interface') || text.contains('query'), isTrue);
    });

    test('si console source does not contain hard-coded secrets', () {
      final String text = SourceTestUtils.readAllConcatenated('lib/features/si_console').toLowerCase();
      expect(text.contains('service_role'), isFalse);
      expect(text.contains('sb_secret'), isFalse);
      expect(RegExp(r'private[_-]?key').hasMatch(text), isFalse);
      expect(RegExp(r'bearer\s+[a-z0-9\-\._~\+/]+=*').hasMatch(text), isFalse);
    });

    test('si console remains linked from navigation shell', () {
      final String navText = SourceTestUtils.readText(File('lib/app/navigation_shell.dart'));
      expect(navText.contains('SIConsoleScreen'), isTrue);
    });
  });
}
