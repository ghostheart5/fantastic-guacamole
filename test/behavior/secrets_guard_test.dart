import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '_support/source_test_utils.dart';

void main() {
  group('Secrets guard', () {
    test('source and tools do not contain obvious hard-coded secrets', () {
      final List<String> offenders = <String>[];
      final RegExp tokenPattern = RegExp(
        r'''(service[_-]?role[_-]?key\s*[:=]\s*['"][^'"]+['"]|sb_secret_[A-Za-z0-9]{16,}|-----BEGIN PRIVATE KEY-----|bearer\s+[A-Za-z0-9\-._~+/]{20,}=*)''',
        caseSensitive: false,
      );

      final List<File> files = <File>[
        ...SourceTestUtils.dartFilesUnder('lib'),
        ...SourceTestUtils.dartFilesUnder('test'),
        ...Directory('tools')
            .listSync(recursive: true)
            .whereType<File>()
            .where((File file) => file.path.endsWith('.ps1')),
      ];

      for (final File file in files) {
        final String path = SourceTestUtils.normalizePath(file.path);
        final String lowerPath = path.toLowerCase();
        if (lowerPath.endsWith('/firebase_options.dart') ||
            lowerPath.endsWith('/secrets_guard_test.dart') ||
            lowerPath.endsWith('/release_readiness_contract_test.dart') ||
            lowerPath.endsWith('/google_play_readiness_contract_test.dart') ||
            lowerPath.endsWith('/si_console_release_protection_test.dart') ||
            lowerPath.endsWith('/auth_release_protection_test.dart') ||
            lowerPath.endsWith('/si_console_contract_test.dart')) {
          continue;
        }
        final String text = SourceTestUtils.readText(file);
        if (tokenPattern.hasMatch(text)) {
          offenders.add(path);
        }

        final String lower = text.toLowerCase();
        if (lower.contains('supabase.co') && lower.contains('service_role')) {
          offenders.add(path);
        }
      }

      expect(offenders, isEmpty, reason: 'Potential secret leakage detected: $offenders');
    });
  });
}
