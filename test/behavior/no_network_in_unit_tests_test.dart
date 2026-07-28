import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '_support/source_test_utils.dart';

void main() {
  group('No network in unit/behavior/architecture tests', () {
    test('test suites avoid uncontrolled live network/platform dependencies', () {
      final List<String> offenders = <String>[];
      final List<File> files = <File>[
        ...SourceTestUtils.dartFilesUnder('test/unit'),
        ...SourceTestUtils.dartFilesUnder('test/behavior'),
        ...SourceTestUtils.dartFilesUnder('test/architecture'),
      ];

      const List<String> banned = <String>[
        'http://',
        'https://',
        'Supabase.initialize(',
        'Firebase.initializeApp(',
        'adb ',
        'monkey',
      ];

      for (final File file in files) {
        final String path = SourceTestUtils.normalizePath(file.path).toLowerCase();
        if (path.endsWith('/no_network_in_unit_tests_test.dart')) {
          continue;
        }
        final String text = SourceTestUtils.readText(file);
        final String lower = text.toLowerCase();
        final bool hasBanned = banned.any((String token) => lower.contains(token.toLowerCase()));
        final bool platformChannelWithoutMock =
            lower.contains('methodchannel(') && !lower.contains('setmockmethodcallhandler');

        if (hasBanned || platformChannelWithoutMock) {
          offenders.add(SourceTestUtils.normalizePath(file.path));
        }
      }

      expect(offenders, isEmpty, reason: 'Uncontrolled network/platform dependencies found: $offenders');
    });
  });
}
