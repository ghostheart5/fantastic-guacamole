import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/features/home/ui/smart_coach_screen.dart';
import 'package:fantastic_guacamole/state/controllers/coach_query_controller.dart';
import 'package:fantastic_guacamole/state/controllers/voice_controller.dart';
import 'package:fantastic_guacamole/state/state/emotional_state.dart';
import 'package:fantastic_guacamole/system/voice/voice_service.dart';
import 'package:fantastic_guacamole/tutorial/tutorial_target_registry.dart';
import 'package:fantastic_guacamole/ui/widgets/error_boundary_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'renders ErrorBoundary and recovers on retry after coach request failure',
    (WidgetTester tester) async {
      final ProviderContainer container = ProviderContainer(
        overrides: [
          coachQueryControllerProvider.overrideWith(
            _FlakyCoachQueryController.new,
          ),
          voiceServiceProvider.overrideWithValue(_NoopVoiceService()),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: ErrorBoundary(child: SmartCoachScreen()),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      await Logger.withMutedErrors(() async {
        await _tapPrimaryCoachButton(tester);
        await tester.pump(const Duration(milliseconds: 500));
      });

      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await _tapPrimaryCoachButton(tester);
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Something went wrong'), findsNothing);

      final Finder recoveredMessage = find.text('Recovered coaching response.');
      await tester.scrollUntilVisible(
        recoveredMessage,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(recoveredMessage, findsOneWidget);
    },
  );

  testWidgets(
    'sends follow-up and renders exchange after initial coaching response',
    (WidgetTester tester) async {
      final ProviderContainer container = ProviderContainer(
        overrides: [
          coachQueryControllerProvider.overrideWith(
            _ConversationalCoachQueryController.new,
          ),
          voiceServiceProvider.overrideWithValue(_NoopVoiceService()),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: ErrorBoundary(child: SmartCoachScreen()),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      await _tapPrimaryCoachButton(tester);
      await tester.pump(const Duration(milliseconds: 500));

      final Finder initialMessage = find.text('Initial coaching response.');
      await tester.scrollUntilVisible(
        initialMessage,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(initialMessage, findsOneWidget);

      const String followUpQuestion = 'What should I do first?';
      await tester.enterText(find.byType(TextField).last, followUpQuestion);
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pump(const Duration(milliseconds: 600));

      final Finder followUpReply = find.text(
        'Follow-up reply for: What should I do first?',
      );
      await tester.scrollUntilVisible(
        followUpReply,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(followUpQuestion), findsOneWidget);
      expect(followUpReply, findsOneWidget);
    },
  );

  testWidgets(
    'follow-up crisis keyword shows crisis dialog and does not append reply',
    (WidgetTester tester) async {
      final ProviderContainer container = ProviderContainer(
        overrides: [
          coachQueryControllerProvider.overrideWith(
            _CrisisFollowUpCoachQueryController.new,
          ),
          voiceServiceProvider.overrideWithValue(_NoopVoiceService()),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: ErrorBoundary(child: SmartCoachScreen()),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      await _tapPrimaryCoachButton(tester);
      await tester.pump(const Duration(milliseconds: 500));

      const String crisisText = 'I feel like I want to kill myself right now';
      await tester.enterText(find.byType(TextField).last, crisisText);
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text("You're not alone"), findsOneWidget);
      expect(find.text('OK'), findsOneWidget);
      expect(find.textContaining('Follow-up reply for:'), findsNothing);
    },
  );

  testWidgets('creator entry action is visible and tappable', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = ProviderContainer(
      overrides: [
        coachQueryControllerProvider.overrideWith(
          _ConversationalCoachQueryController.new,
        ),
        voiceServiceProvider.overrideWithValue(_NoopVoiceService()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: ErrorBoundary(child: SmartCoachScreen()),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    final Finder creatorEntry = find.text('OPEN CREATOR TO MAKE TASK');
    expect(creatorEntry, findsOneWidget);

    await tester.tap(creatorEntry);
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull);
  });
}

class _FlakyCoachQueryController extends CoachQueryController {
  _FlakyCoachQueryController(super.ref);

  int _attempts = 0;

  @override
  bool detectsCrisis(String text) => false;

  @override
  Future<CoachCoachingResult> requestCoaching({
    required double energy,
    required EmotionalState emotion,
    required String notes,
    required List<Map<String, String>> history,
    required String? previousSavedNotes,
  }) async {
    _attempts += 1;
    if (_attempts == 1) {
      throw StateError('simulated coach failure');
    }

    return const CoachCoachingResult(
      prompt: 'practical coaching check-in',
      message: 'Recovered coaching response.',
      savedNotes: null,
    );
  }

  @override
  Future<String> requestFollowUp({
    required String input,
    required double energy,
    required EmotionalState emotion,
    required String reflection,
    required List<Map<String, String>> history,
  }) async {
    return 'Recovered follow-up';
  }
}

class _NoopVoiceService extends VoiceService {
  @override
  Future<void> speak(String text) async {}

  @override
  Future<void> stop() async {}
}

class _ConversationalCoachQueryController extends CoachQueryController {
  _ConversationalCoachQueryController(super.ref);

  @override
  bool detectsCrisis(String text) => false;

  @override
  Future<CoachCoachingResult> requestCoaching({
    required double energy,
    required EmotionalState emotion,
    required String notes,
    required List<Map<String, String>> history,
    required String? previousSavedNotes,
  }) async {
    return const CoachCoachingResult(
      prompt: 'practical coaching check-in',
      message: 'Initial coaching response.',
      savedNotes: null,
    );
  }

  @override
  Future<String> requestFollowUp({
    required String input,
    required double energy,
    required EmotionalState emotion,
    required String reflection,
    required List<Map<String, String>> history,
  }) async {
    return 'Follow-up reply for: $input';
  }
}

class _CrisisFollowUpCoachQueryController extends CoachQueryController {
  _CrisisFollowUpCoachQueryController(super.ref);

  @override
  bool detectsCrisis(String text) => text.toLowerCase().contains('kill myself');

  @override
  Future<CoachCoachingResult> requestCoaching({
    required double energy,
    required EmotionalState emotion,
    required String notes,
    required List<Map<String, String>> history,
    required String? previousSavedNotes,
  }) async {
    return const CoachCoachingResult(
      prompt: 'practical coaching check-in',
      message: 'Initial coaching response.',
      savedNotes: null,
    );
  }

  @override
  Future<String> requestFollowUp({
    required String input,
    required double energy,
    required EmotionalState emotion,
    required String reflection,
    required List<Map<String, String>> history,
  }) async {
    return 'Follow-up reply for: $input';
  }
}

Future<void> _tapPrimaryCoachButton(WidgetTester tester) async {
  final Finder cta = find.byType(TutorialTarget);
  await tester.scrollUntilVisible(
    cta,
    250,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(cta.first, warnIfMissed: false);
  await tester.pump();
}
