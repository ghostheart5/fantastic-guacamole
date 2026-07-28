import 'dart:io';

import 'package:fantastic_guacamole/tutorial/tutorial_progress_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '_support/source_test_utils.dart';

void main() {
  group('JSON roundtrip contract', () {
    test('TutorialProgress roundtrip preserves object equality', () {
      final TutorialProgress original = const TutorialProgress(
        contentVersion: 4,
        started: true,
        hasSeenIntro: true,
      ).markCompleted('step.a');

      final TutorialProgress restored = TutorialProgress.fromJson(original.toJson());
      expect(restored, equals(original));
    });

    test('model files do not define one-sided json serialization', () {
      final List<String> offenders = <String>[];

      for (final File file in SourceTestUtils.dartFilesUnder('lib')) {
        final String path = SourceTestUtils.normalizePath(file.path).toLowerCase();
        if (!path.contains('model')) {
          continue;
        }
        if (path.endsWith('/data/services/ai/models/agent_result.dart') ||
            path.endsWith('/engine/assistant/assistant_models.dart') ||
            path.endsWith('/engine/si/models/si_state.dart') ||
            path.endsWith('/tutorial/tutorial_models.dart')) {
          continue;
        }
        final String text = SourceTestUtils.readText(file);
        final bool isBarrel = path.endsWith('/models.dart') || path.endsWith('/entities.dart');
        final bool hasClass = RegExp(r'\bclass\s+\w+').hasMatch(text);
        if (isBarrel || !hasClass) {
          continue;
        }
        final bool hasToJson = text.contains('toJson(');
        final bool hasFromJson = text.contains('fromJson(');
        final bool hasMapFactory = text.contains('fromMap(') || text.contains('toMap(');
        if (hasToJson != hasFromJson && !hasMapFactory) {
          offenders.add(SourceTestUtils.normalizePath(file.path));
        }
      }

      expect(offenders, isEmpty, reason: 'Model files with one-sided JSON APIs: $offenders');
    });

    test('repositories and services using jsonDecode include safety handling', () {
      final List<String> offenders = <String>[];

      for (final File file in SourceTestUtils.dartFilesUnder('lib')) {
        final String path = SourceTestUtils.normalizePath(file.path).toLowerCase();
        if (!(path.contains('repository') || path.contains('service'))) {
          continue;
        }
        if (path.endsWith('/features/auth/data/repositories/local_identity_repository.dart') ||
            path.endsWith('/features/monetization/data/services/purchase_verification_service.dart') ||
            path.endsWith('/state/services/credit_service.dart') ||
            path.endsWith('/state/services/extended_domain_service.dart')) {
          continue;
        }
        final String text = SourceTestUtils.readText(file);
        if (text.contains('jsonDecode(')) {
          final bool guarded =
              (text.contains('try {') && (text.contains('catch') || text.contains('FormatException'))) ||
              text.contains('jsonDecodeSafe(') ||
              text.contains('??') ||
              text.contains('as Map<String, dynamic>');
          if (!guarded) {
            offenders.add(SourceTestUtils.normalizePath(file.path));
          }
        }
      }

      expect(offenders, isEmpty, reason: 'jsonDecode usage without fallback/guard: $offenders');
    });
  });
}
