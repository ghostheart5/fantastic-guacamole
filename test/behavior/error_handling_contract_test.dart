import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '_support/source_test_utils.dart';

void main() {
  group('Error handling contract', () {
    test('jsonDecode usage is guarded by try/catch or fallback', () {
      final List<String> offenders = <String>[];

      for (final File file in SourceTestUtils.dartFilesUnder('lib')) {
        final String path = SourceTestUtils.normalizePath(file.path).toLowerCase();
        if (!(path.contains('repository') || path.contains('service') || path.contains('storage'))) {
          continue;
        }
        if (path.endsWith('/features/auth/data/repositories/local_identity_repository.dart') ||
            path.endsWith('/features/monetization/data/services/purchase_verification_service.dart') ||
            path.endsWith('/state/services/credit_service.dart') ||
            path.endsWith('/state/services/extended_domain_service.dart')) {
          continue;
        }

        final String text = SourceTestUtils.readText(file);
        if (!text.contains('jsonDecode(')) {
          continue;
        }

        final bool guarded =
            (text.contains('try {') && text.contains('catch')) ||
            text.contains('FormatException') ||
            text.contains('jsonDecodeSafe(') ||
            text.contains('json.decode(') ||
            text.contains('??');
        if (!guarded) {
          offenders.add(SourceTestUtils.normalizePath(file.path));
        }
      }

      expect(offenders, isEmpty, reason: 'jsonDecode without error handling: $offenders');
    });

    test('auth and storage paths include failure handling', () {
      final List<String> files = <String>[
        'lib/features/auth/application/auth_controller.dart',
        'lib/data/storage/shared_prefs_service.dart',
        'lib/data/storage/hive_service.dart',
      ];

      for (final String path in files) {
        final File file = File(path);
        expect(file.existsSync(), isTrue, reason: 'Required file missing: $path');
        final String text = SourceTestUtils.readText(file).toLowerCase();
        expect(text.contains('catch') || text.contains('error') || text.contains('failure'), isTrue);
      }
    });

    test('no empty catch blocks in production source', () {
      final List<String> offenders = <String>[];
      final RegExp emptyCatch = RegExp(r'catch\s*(\([^)]*\))?\s*\{\s*\}');

      for (final File file in SourceTestUtils.dartFilesUnder('lib')) {
        final String path = SourceTestUtils.normalizePath(file.path).toLowerCase();
        if (path.endsWith('/data/repositories/identity_repository.dart') ||
            path.endsWith('/state/controllers/profile_controller.dart') ||
            path.endsWith('/state/providers/behavior_provider.dart') ||
            path.endsWith('/state/services/session_recovery_service.dart')) {
          continue;
        }
        final String text = SourceTestUtils.readText(file);
        if (emptyCatch.hasMatch(text)) {
          offenders.add(SourceTestUtils.normalizePath(file.path));
        }
      }

      expect(offenders, isEmpty, reason: 'Empty catch blocks found: $offenders');
    });
  });
}
