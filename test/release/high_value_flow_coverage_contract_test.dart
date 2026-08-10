import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../behavior/_support/source_test_utils.dart';

void main() {
  group('High-value flow coverage contract', () {
    test('onboarding remains a 2-slide setup with expected messaging', () {
      final File onboardingFile = File(
        'lib/features/onboarding/ui/onboarding_screen.dart',
      );
      expect(onboardingFile.existsSync(), isTrue);

      final String text = SourceTestUtils.readText(onboardingFile);

      expect(text.contains('static const int _totalPages = 2;'), isTrue);
      expect(text.contains("'START SETUP'"), isTrue);
      expect(text.contains("'Create, schedule, and review'"), isTrue);
      expect(
        text.contains(
          'Choose when they happen, then view everything on your Timeline.',
        ),
        isTrue,
      );
      expect(
        text.contains('Smart Planner helps you decide what to focus on next.'),
        isTrue,
      );
      expect(
        text.contains(
          'SI Console helps you understand your goals, progress, and planning signals.',
        ),
        isTrue,
      );
    });

    test('creator setup keeps create-to-timeline review loop', () {
      final File creatorFile = File(
        'lib/features/creator/ui/creator_screen.dart',
      );
      expect(creatorFile.existsSync(), isTrue);

      final String text = SourceTestUtils.readText(creatorFile);

      expect(
        text.contains('final bool shouldAutoOpenTimeline = !ref.read('),
        isTrue,
      );
      expect(
        text.contains("'First item created. Reviewing it on your timeline...'"),
        isTrue,
      );
      expect(text.contains('label: \'REVIEW TIMELINE\''), isTrue);
      expect(
        text.contains('ref.read(appFlowProvider.notifier).toTimeline();'),
        isTrue,
      );
      expect(
        text.contains(
          'After saving, ChronoSpark will show it on your Timeline.',
        ),
        isTrue,
      );
    });

    test(
      'smart planner follow-up keeps input on timeout/error and clears on success only',
      () {
        final File smartCoachFile = File(
          'lib/features/home/ui/smart_coach_screen.dart',
        );
        expect(smartCoachFile.existsSync(), isTrue);

        final String text = SourceTestUtils.readText(smartCoachFile);
        final int clearIndex = text.indexOf('_followUpController.clear();');
        final int addReplyIndex = text.indexOf(
          '_followUps.add(SmartCoachExchange(question: text, answer: reply));',
        );
        final int timeoutIndex = text.indexOf(
          "_followUpError = 'Follow-up timed out. Try a shorter prompt.';",
        );
        final int errorIndex = text.indexOf(
          "_followUpError = 'Follow-up could not be sent. Try again.';",
        );

        expect(text.contains('Future<void> _sendFollowUp() async {'), isTrue);
        expect(clearIndex, greaterThan(-1));
        expect(addReplyIndex, greaterThan(-1));
        expect(timeoutIndex, greaterThan(-1));
        expect(errorIndex, greaterThan(-1));
        expect(clearIndex, lessThan(addReplyIndex));
      },
    );

    test(
      'settings audio wiring initializes once and updates through setting listeners',
      () {
        final File settingsFile = File(
          'lib/features/settings/ui/settings_screen.dart',
        );
        expect(settingsFile.existsSync(), isTrue);

        final String text = SourceTestUtils.readText(settingsFile);

        expect(
          text.contains('WidgetsBinding.instance.addPostFrameCallback((_) {'),
          isTrue,
        );
        expect(text.contains('_syncAudioSettings();'), isTrue);
        expect(
          text.contains('ref.listen<bool>(\n      soundEnabledProvider,'),
          isTrue,
        );
        expect(
          text.contains(
            'ref.listen<bool>(\n      advancedAudioProfileEnabledProvider,',
          ),
          isTrue,
        );
        expect(
          text.contains(
            'ref.listen<bool>(\n      hapticFeedbackEnabledProvider,',
          ),
          isTrue,
        );
      },
    );

    test(
      'si console keeps inline degradation banner when messages already exist',
      () {
        final File siConsoleFile = File(
          'lib/features/si_console/ui/si_console_screen.dart',
        );
        expect(siConsoleFile.existsSync(), isTrue);

        final String text = SourceTestUtils.readText(siConsoleFile);

        expect(
          text.contains('(consoleError != null && _messages.isEmpty)'),
          isTrue,
        );
        expect(text.contains('if (consoleError != null)'), isTrue);
        expect(text.contains('SI context is limited right now.'), isTrue);
        expect(
          text.contains('Some intelligence data could not refresh.'),
          isTrue,
        );
      },
    );
  });
}
