import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../behavior/_support/source_test_utils.dart';

void main() {
  group('Permissions and privacy release contract', () {
    test('permission dependencies have rationale source paths', () {
      final String pubspec = SourceTestUtils.readText(
        File('pubspec.yaml'),
      ).toLowerCase();
      final bool usesPermissionHandler = pubspec.contains('permission_handler');
      final bool usesMic = pubspec.contains('speech_to_text');
      final bool usesNotifications =
          pubspec.contains('flutter_local_notifications') ||
          pubspec.contains('firebase_messaging');
      final bool usesCameraOrPicker =
          pubspec.contains('image_picker') || pubspec.contains('camera');

      final String libText = SourceTestUtils.readAllConcatenated(
        'lib',
      ).toLowerCase();

      if (usesPermissionHandler ||
          usesMic ||
          usesNotifications ||
          usesCameraOrPicker) {
        expect(
          libText.contains('permission') ||
              libText.contains('rationale') ||
              libText.contains('allow'),
          isTrue,
        );
      }
    });

    test('privacy policy and security docs are present', () {
      final bool hasPrivacyDoc =
          File('privacy.html').existsSync() ||
          File('assets/legal/privacy_policy.txt').existsSync();
      final bool hasSecurityDoc = File('SECURITY.md').existsSync();
      expect(hasPrivacyDoc, isTrue);
      expect(hasSecurityDoc, isTrue);
    });

    test('permission prompts are not hidden inside build methods', () {
      final List<String> offenders = <String>[];
      for (final File file in SourceTestUtils.dartFilesUnder('lib')) {
        final String path = SourceTestUtils.normalizePath(
          file.path,
        ).toLowerCase();
        if (!path.contains('/ui/') && !path.contains('/widgets/')) {
          continue;
        }

        final String text = SourceTestUtils.readText(file);
        final int buildIndex = text.indexOf('Widget build(');
        if (buildIndex < 0) {
          continue;
        }

        final String buildBody = text.substring(buildIndex).toLowerCase();
        if (buildBody.contains('permission.request(')) {
          offenders.add(path);
        }
      }

      expect(
        offenders,
        isEmpty,
        reason:
            'Permission prompts should not run in build methods: $offenders',
      );
    });
  });
}
