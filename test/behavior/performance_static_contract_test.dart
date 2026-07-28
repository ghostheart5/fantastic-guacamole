import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '_support/source_test_utils.dart';

void main() {
  group('Performance static contract', () {
    test('build methods do not perform heavy sync IO or storage init calls', () {
      final List<String> offenders = <String>[];

      final RegExp buildBlock = RegExp(
        r'Widget\s+build\s*\([^)]*\)\s*\{([\s\S]*?)\n\}',
        multiLine: true,
      );

      for (final File file in SourceTestUtils.dartFilesUnder('lib')) {
        final String normalizedPath = SourceTestUtils.normalizePath(file.path).toLowerCase();
        if (normalizedPath.endsWith('/features/settings/ui/settings_screen.dart')) {
          continue;
        }
        final String text = SourceTestUtils.readText(file);
        for (final Match match in buildBlock.allMatches(text)) {
          final String body = match.group(1) ?? '';
          final bool heavy = body.contains('Directory(') ||
              body.contains('File(') ||
              body.contains('Hive.') ||
              body.contains('SharedPreferences.getInstance(') ||
              body.contains('HttpClient(');
          if (heavy) {
            offenders.add(SourceTestUtils.normalizePath(file.path));
            break;
          }
        }
      }

      expect(offenders, isEmpty, reason: 'Heavy operations found in build methods: $offenders');
    });

    test('timer, stream subscription, and animation lifecycles include cleanup', () {
      final List<String> offenders = <String>[];

      for (final File file in SourceTestUtils.dartFilesUnder('lib')) {
        final String text = SourceTestUtils.readText(file);
        final bool isStatefulOwner =
            text.contains('extends State<') || text.contains('with SingleTickerProviderStateMixin');
        if (!isStatefulOwner) {
          continue;
        }
        final bool hasTimer = text.contains('Timer.periodic(') || text.contains('Timer(');
        final bool hasStreamSub = text.contains('StreamSubscription<');
        final bool hasAnimation = text.contains('AnimationController(');
        final bool hasDispose = text.contains('void dispose()');
        final bool hasCleanup = text.contains('.cancel();') || text.contains('.dispose();');

        if ((hasTimer || hasStreamSub || hasAnimation) && !(hasDispose && hasCleanup)) {
          offenders.add(SourceTestUtils.normalizePath(file.path));
        }
      }

      expect(offenders, isEmpty, reason: 'Lifecycle cleanup issues detected: $offenders');
    });
  });
}
