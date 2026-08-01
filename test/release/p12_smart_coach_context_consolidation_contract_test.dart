import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../behavior/_support/source_test_utils.dart';

void main() {
  group('P1-2 smart coach context consolidation contract', () {
    test('shared assistant context helper is present and reused by both coach request paths', () {
      final File file = File('lib/state/controllers/coach_query_controller.dart');
      expect(file.existsSync(), isTrue);

      final String text = SourceTestUtils.readText(file);

      expect(text.contains('class _CoachAssistantContextData'), isTrue);
      expect(text.contains('_buildAssistantContextData('), isTrue);

      final int helperCallCount =
          '_buildAssistantContextData('.allMatches(text).length;
      expect(helperCallCount >= 3, isTrue);

      expect(text.contains('Future<CoachCoachingResult> requestCoaching('), isTrue);
      expect(text.contains('Future<String> requestFollowUp('), isTrue);
    });
  });
}
