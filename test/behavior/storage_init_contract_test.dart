import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '_support/source_test_utils.dart';

void main() {
  group('Storage init contract', () {
    test('SharedPrefs and Hive services expose init and io methods', () {
      final File shared = File('lib/data/storage/shared_prefs_service.dart');
      final File hive = File('lib/data/storage/hive_service.dart');

      expect(shared.existsSync(), isTrue);
      expect(hive.existsSync(), isTrue);

      final String sharedText = SourceTestUtils.readText(shared);
      final String hiveText = SourceTestUtils.readText(hive);

      expect(sharedText.contains('init('), isTrue);
      expect(sharedText.contains('save('), isTrue);
      expect(sharedText.contains('load('), isTrue);
      expect(sharedText.contains('delete('), isTrue);

      expect(hiveText.contains('init('), isTrue);
      expect(
        hiveText.contains('openBox') || hiveText.contains('openLazyBox'),
        isTrue,
      );
    });

    test('storage code includes error/fallback handling and no UI imports', () {
      final List<String> offenders = <String>[];
      final List<File> files = <File>[
        File('lib/data/storage/shared_prefs_service.dart'),
        File('lib/data/storage/hive_service.dart'),
      ].where((File file) => file.existsSync()).toList(growable: false);

      for (final File file in files) {
        final String text = SourceTestUtils.readText(file);
        final String lower = text.toLowerCase();

        final bool hasErrorPath =
            lower.contains('catch') ||
            lower.contains('fallback') ||
            lower.contains('degraded') ||
            lower.contains('stateerror');
        final bool importsUi =
            lower.contains('/screen') ||
            lower.contains('/widget') ||
            lower.contains('material.dart');

        if (!hasErrorPath || importsUi) {
          offenders.add(SourceTestUtils.normalizePath(file.path));
        }
      }

      expect(
        offenders,
        isEmpty,
        reason: 'Storage contract violations: $offenders',
      );
    });

    test('startup opens repository boxes before the app becomes ready', () {
      final File bootstrap = File('lib/app/startup/app_bootstrap.dart');
      final String bootstrapText = SourceTestUtils.readText(bootstrap);

      expect(
        bootstrapText.contains('HiveService.init(warmupBoxes: true)'),
        isTrue,
        reason:
            'Repositories use synchronous Hive access, so startup must open '
            'their boxes before rendering feature screens.',
      );
      expect(
        bootstrapText.indexOf('HiveService.configureSecureStore') <
            bootstrapText.indexOf('HiveService.init(warmupBoxes: true)'),
        isTrue,
        reason: 'Encrypted boxes need their cipher before they are opened.',
      );

      final String hiveText = SourceTestUtils.readText(
        File('lib/data/storage/hive_service.dart'),
      );
      expect(
        hiveText.contains('HiveBoxes.encryptedBoxes.difference('),
        isTrue,
        reason:
            'Warmup must derive secondary boxes from the complete declaration '
            'so synchronous repositories never receive a closed box.',
      );
      expect(
        hiveText.contains('CHRONOSPARK_HIVE_BOX_OPEN_FAILED') &&
            hiveText.contains('rethrow;'),
        isTrue,
        reason:
            'A required box open failure must fail startup instead of surfacing '
            'later as a synchronous repository crash.',
      );
    });
  });
}
