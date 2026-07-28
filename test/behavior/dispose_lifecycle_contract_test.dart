import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '_support/source_test_utils.dart';

void main() {
  group('Dispose lifecycle contract', () {
    test('stateful resources are disposed or canceled when used', () {
      final List<String> offenders = <String>[];

      const Map<String, String> resources = <String, String>{
        'AnimationController': '.dispose();',
        'TextEditingController': '.dispose();',
        'FocusNode': '.dispose();',
        'ScrollController': '.dispose();',
        'StreamSubscription<': '.cancel();',
        'Timer': '.cancel();',
      };

      for (final File file in SourceTestUtils.dartFilesUnder('lib')) {
        final String text = SourceTestUtils.readText(file);
        final String lower = text.toLowerCase();
        final bool externalTextController =
          text.contains('final TextEditingController controller;') ||
          text.contains('required this.controller');
        final bool hasLifecycleHook =
            text.contains('void dispose()') ||
            text.contains('onDispose(') ||
            text.contains('ref.onDispose(');
        final bool hasCleanupCall =
            text.contains('.cancel();') ||
            text.contains('.cancel(') ||
            text.contains('.dispose();') ||
            text.contains('.dispose(');
        for (final MapEntry<String, String> entry in resources.entries) {
          if (entry.key == 'TextEditingController' && externalTextController) {
            continue;
          }
          if (text.contains(entry.key) && !(hasLifecycleHook && hasCleanupCall || lower.contains(entry.value.toLowerCase()))) {
            offenders.add('${SourceTestUtils.normalizePath(file.path)}::${entry.key}');
          }
        }
      }

      expect(offenders, isEmpty, reason: 'Resource lifecycle cleanup missing: $offenders');
    });

    test('change notifier controllers with resources implement dispose', () {
      final List<String> offenders = <String>[];

      for (final File file in SourceTestUtils.dartFilesUnder('lib')) {
        final String path = SourceTestUtils.normalizePath(file.path).toLowerCase();
        if (!path.contains('controller')) {
          continue;
        }

        final String text = SourceTestUtils.readText(file);
        final bool createsResources = text.contains('StreamSubscription<') ||
            text.contains('Timer(') ||
            text.contains('AnimationController(') ||
            text.contains('TextEditingController(');
        final bool hasDispose =
          text.contains('void dispose()') ||
          text.contains('ref.onDispose(') ||
          text.contains('onDispose(');

        if (createsResources && !hasDispose) {
          offenders.add(SourceTestUtils.normalizePath(file.path));
        }
      }

      expect(offenders, isEmpty, reason: 'Controllers missing dispose for owned resources: $offenders');
    });
  });
}
