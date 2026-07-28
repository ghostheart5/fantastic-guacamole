import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../behavior/_support/source_test_utils.dart';

void main() {
  group('Notification release contract', () {
    test('notification source and schedule/cancel paths are present when dependency exists', () {
      final String pubspec = SourceTestUtils.readText(File('pubspec.yaml')).toLowerCase();
      final bool hasNotificationsDependency = pubspec.contains('flutter_local_notifications') ||
          pubspec.contains('firebase_messaging');

      final List<File> notificationFiles = SourceTestUtils.dartFilesUnder('lib')
          .where((File file) {
            final String path = SourceTestUtils.normalizePath(file.path).toLowerCase();
            return path.contains('notification') || path.contains('messaging');
          })
          .toList(growable: false);

      if (!hasNotificationsDependency) {
        expect(notificationFiles, isEmpty);
        return;
      }

      expect(notificationFiles, isNotEmpty, reason: 'Notification deps exist but no notification source files were found.');

      final String text = notificationFiles.map(SourceTestUtils.readText).join('\n').toLowerCase();
      expect(text.contains('schedule'), isTrue);
      expect(text.contains('cancel'), isTrue);
      expect(text.contains('tap') || text.contains('payload') || text.contains('deeplink'), isTrue);
    });

    test('notification code does not schedule in widget build methods', () {
      final List<String> offenders = <String>[];

      for (final File file in SourceTestUtils.dartFilesUnder('lib')) {
        final String path = SourceTestUtils.normalizePath(file.path).toLowerCase();
        if (!path.contains('notification') && !path.contains('messaging')) {
          continue;
        }

        final String text = SourceTestUtils.readText(file);
        final int buildIndex = text.indexOf('Widget build(');
        if (buildIndex < 0) {
          continue;
        }

        final String buildBody = text.substring(buildIndex).toLowerCase();
        if (buildBody.contains('schedule(')) {
          offenders.add(path);
        }
      }

      expect(offenders, isEmpty, reason: 'Notification scheduling should not run in build: $offenders');
    });
  });
}
