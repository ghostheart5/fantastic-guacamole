import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../behavior/_support/source_test_utils.dart';

void main() {
  group('Google Play readiness contract', () {
    test('android manifest and sdk configuration are present', () {
      final File manifest = File('android/app/src/main/AndroidManifest.xml');
      final File gradle = File('android/app/build.gradle.kts');

      expect(manifest.existsSync(), isTrue);
      expect(gradle.existsSync(), isTrue);

      final String gradleText = SourceTestUtils.readText(gradle).toLowerCase();
      expect(
        gradleText.contains('minsdk') || gradleText.contains('minsdkversion'),
        isTrue,
      );
      expect(
        gradleText.contains('targetsdk') ||
            gradleText.contains('targetsdkversion'),
        isTrue,
      );
    });

    test('Google Play Billing is pinned to the supported major version', () {
      final String gradleText = SourceTestUtils.readText(
        File('android/app/build.gradle.kts'),
      );

      expect(gradleText, contains('com.android.billingclient:billing:8.0.0'));
      expect(
        gradleText,
        isNot(
          RegExp(r'com\.android\.billingclient:billing:[0-7]\.(?:\d+\.)?\d+'),
        ),
      );
    });

    test('release signing secrets are not committed in obvious plaintext', () {
      final List<String> offenders = <String>[];

      for (final File file in SourceTestUtils.filesUnder('android')) {
        final String path = SourceTestUtils.normalizePath(
          file.path,
        ).toLowerCase();
        if (!path.endsWith('.gradle') &&
            !path.endsWith('.kts') &&
            !path.endsWith('.properties')) {
          continue;
        }
        if (path.endsWith('/key.properties')) {
          continue;
        }

        final String text = SourceTestUtils.readText(file).toLowerCase();
        final bool isProperties = path.endsWith('.properties');
        final bool hasPlainPasswordInProperties =
            isProperties &&
            (RegExp(
                  r'^\s*keypassword\s*=\s*[^\s#].+$',
                  multiLine: true,
                ).hasMatch(text) ||
                RegExp(
                  r'^\s*storepassword\s*=\s*[^\s#].+$',
                  multiLine: true,
                ).hasMatch(text));
        final bool hasHardSecretTokens =
            text.contains('service_role_key') ||
            RegExp(r'\bsb_secret_[a-z0-9]{16,}\b').hasMatch(text);
        if (hasPlainPasswordInProperties || hasHardSecretTokens) {
          offenders.add(path);
        }
      }

      expect(
        offenders,
        isEmpty,
        reason:
            'Potential plaintext release secrets in android config: $offenders',
      );
    });

    test(
      'release command or docs exist and debug-only shipping markers are absent',
      () {
        final bool hasReleaseScript =
            File('tools/run_full_test_audit.ps1').existsSync() ||
            File('README.md').existsSync();
        expect(hasReleaseScript, isTrue);

        final String libText = SourceTestUtils.readAllConcatenated(
          'lib',
        ).toLowerCase();
        expect(libText.contains('debug-only shipping marker'), isFalse);
      },
    );
  });
}
