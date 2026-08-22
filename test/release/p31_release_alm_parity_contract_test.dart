import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../behavior/_support/source_test_utils.dart';

void main() {
  group('P3-1 release ALM parity contract', () {
    test(
      'manual release preflight workflow supports production staging and tester profiles',
      () {
        final File preflightWorkflow = File(
          '.github/workflows/release-preflight.yml',
        );
        expect(preflightWorkflow.existsSync(), isTrue);

        final String text = SourceTestUtils.readText(preflightWorkflow);

        expect(text.contains('workflow_dispatch:'), isTrue);
        expect(text.contains('default: production'), isTrue);
        expect(text.contains('- production'), isTrue);
        expect(text.contains('- staging'), isTrue);
        expect(text.contains('- tester'), isTrue);
        expect(text.contains('./scripts/security_secret_guard.ps1'), isTrue);
        expect(text.contains('./scripts/release_guard.ps1'), isTrue);
        expect(text.contains('./scripts/safe_release_preflight.ps1'), isTrue);
      },
    );

    test(
      'android release workflow keeps security and production guardrails',
      () {
        final File androidReleaseWorkflow = File(
          '.github/workflows/android-release.yml',
        );
        expect(androidReleaseWorkflow.existsSync(), isTrue);

        final String text = SourceTestUtils.readText(androidReleaseWorkflow);

        expect(text.contains("tags:\n      - 'v*.*.*'"), isTrue);
        expect(text.contains('./scripts/security_secret_guard.ps1'), isTrue);
        expect(text.contains('resolve-authoritative-gate:'), isTrue);
        expect(text.contains('production-backend-gate:'), isTrue);
        expect(text.contains('public-infrastructure-gate:'), isTrue);
        expect(text.contains('Download exact gated AAB and manifest'), isTrue);
        expect(text.contains('flutter build appbundle'), isFalse);
      },
    );

    test(
      'repo still contains declared release workflows from ALM audit scope',
      () {
        const List<String> requiredWorkflows = <String>[
          '.github/workflows/android-release.yml',
          '.github/workflows/release-preflight.yml',
          '.github/workflows/linux-release.yml',
          '.github/workflows/main.yml',
        ];

        final List<String> missing = requiredWorkflows
            .where((String path) => !File(path).existsSync())
            .toList(growable: false);

        expect(
          missing,
          isEmpty,
          reason: 'Missing ALM workflow files: $missing',
        );
      },
    );

    test('goldens stay strict on their canonical Windows runner', () {
      final String ciWorkflow = SourceTestUtils.readText(
        File('.github/workflows/dart.yml'),
      );
      final String testWorkflow = SourceTestUtils.readText(
        File('.github/workflows/tests.yml'),
      );

      expect(
        ciWorkflow,
        contains(
          'flutter test --coverage --concurrency=1 --exclude-tags=golden',
        ),
      );
      expect(
        testWorkflow,
        contains('flutter test --coverage --exclude-tags=golden'),
      );
      expect(testWorkflow, contains('name: Golden Tests (Windows)'));
      expect(testWorkflow, contains('runs-on: windows-latest'));
      expect(
        testWorkflow,
        contains('flutter test test/golden --concurrency=1'),
      );
      expect(testWorkflow, isNot(contains('--update-goldens')));
    });
  });
}
