import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../behavior/_support/source_test_utils.dart';

void main() {
  group('P1-2 smart coach context consolidation contract', () {
    test(
      'shared assistant context helper is present and reused by both coach request paths',
      () {
        final File file = File(
          'lib/state/controllers/coach_query_controller.dart',
        );
        expect(file.existsSync(), isTrue);

        final String text = SourceTestUtils.readText(file);

        expect(text.contains('class _CoachAssistantContextData'), isTrue);
        expect(text.contains('_buildAssistantContextData('), isTrue);

        final int helperCallCount = '_buildAssistantContextData('
            .allMatches(text)
            .length;
        expect(helperCallCount >= 3, isTrue);

        expect(
          text.contains('Future<CoachCoachingResult> requestCoaching('),
          isTrue,
        );
        expect(text.contains('Future<String> requestFollowUp('), isTrue);
      },
    );

    test(
      'shared coach AI context helper exists and is reused by both request paths',
      () {
        final File file = File(
          'lib/state/controllers/coach_query_controller.dart',
        );
        expect(file.existsSync(), isTrue);

        final String text = SourceTestUtils.readText(file);

        expect(
          text.contains('Map<String, dynamic> _buildCoachAIContext('),
          isTrue,
        );

        final int helperCallCount = '_buildCoachAIContext('
            .allMatches(text)
            .length;
        expect(helperCallCount >= 3, isTrue);
      },
    );

    test(
      'SI console context assembly uses shared summary and signal helpers',
      () {
        final File controllerFile = File(
          'lib/state/controllers/ai_controller.dart',
        );
        final File helpersFile = File(
          'lib/state/controllers/ai_controller.helpers.dart',
        );
        expect(controllerFile.existsSync(), isTrue);
        expect(helpersFile.existsSync(), isTrue);

        final String controllerText = SourceTestUtils.readText(controllerFile);
        final String helpersText = SourceTestUtils.readText(helpersFile);

        expect(
          helpersText.contains('List<String> summarizeTimelineTitles('),
          isTrue,
        );
        expect(
          helpersText.contains('List<String> summarizeCompletionEvents('),
          isTrue,
        );
        expect(
          helpersText.contains('List<String> summarizeRoutineNames('),
          isTrue,
        );
        expect(
          helpersText.contains('List<String> summarizeScheduledTaskTitles('),
          isTrue,
        );
        expect(
          helpersText.contains(
            'Map<String, dynamic> buildSIConsoleChronosparkSignals(',
          ),
          isTrue,
        );

        expect(controllerText.contains('summarizeTimelineTitles('), isTrue);
        expect(controllerText.contains('summarizeCompletionEvents('), isTrue);
        expect(controllerText.contains('summarizeRoutineNames('), isTrue);
        expect(
          controllerText.contains('summarizeScheduledTaskTitles('),
          isTrue,
        );
        expect(
          controllerText.contains('buildSIConsoleChronosparkSignals('),
          isTrue,
        );
      },
    );
  });
}
