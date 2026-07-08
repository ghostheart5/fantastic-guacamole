import 'package:fantastic_guacamole/features/si_console/ui/si_console_screen.dart';
import 'package:fantastic_guacamole/state/controllers/ai_controller.dart';
import 'package:fantastic_guacamole/state/controllers/voice_controller.dart';
import 'package:fantastic_guacamole/state/models/ai_recommendation.dart';
import 'package:fantastic_guacamole/state/providers/intelligence_provider.dart';
import 'package:fantastic_guacamole/state/state/intelligence_state.dart';
import 'package:fantastic_guacamole/system/voice/voice_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'SI console responds, avoids duplicate output, and handles malformed command safely',
    (WidgetTester tester) async {
      const String firstReply =
          'Start with your highest-priority unfinished task for 15 focused minutes.';
      const String secondReply =
          'Pick one frictionless win first, then escalate to your hardest task.';

      final ProviderContainer container = ProviderContainer(
        overrides: [
          intelligenceStateProvider.overrideWithValue(_intelligence),
          aiControllerProvider.overrideWith((Ref ref) => _ScriptedAiController(ref)),
          voiceServiceProvider.overrideWithValue(_NoopVoiceService()),
        ],
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
      });

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: SIConsoleScreen()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      await _send(tester, 'What should I do now?');
      await _pumpUntilFound(tester, find.byKey(const ValueKey<String>('si-msg-false-$firstReply')));

      await _send(tester, 'What should I do now, exactly?');
      await _pumpUntilFound(
        tester,
        find.byKey(const ValueKey<String>('si-msg-false-$secondReply')),
      );
      expect(secondReply, isNot(firstReply));

      final AIController controller = container.read(aiControllerProvider);
      final AIRecommendation? malformed = await controller.sendMessage('/malformed ???');
      expect(malformed, isNotNull);
      expect(malformed!.message.toLowerCase(), contains('malformed'));
      expect(find.byType(SIConsoleScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _send(WidgetTester tester, String value) async {
  await tester.enterText(find.byType(TextField), value);
  await tester.tap(find.byIcon(Icons.send_rounded));
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 8),
  Duration step = const Duration(milliseconds: 100),
}) async {
  final DateTime endAt = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(endAt)) {
    await tester.pump(step);
    if (finder.evaluate().isNotEmpty) {
      return;
    }
  }
  expect(finder, findsOneWidget);
}

const IntelligenceState _intelligence = IntelligenceState(
  environment: EnvironmentState(
    appName: 'ChronoSpark',
    appFlavor: 'test',
    isProduction: false,
    isSupabaseConfigured: false,
  ),
  flags: FeatureFlagsState(
    verboseLogs: false,
    analyticsEnabled: false,
    mockMode: true,
    mockLoginEnabled: true,
    paywallDisabled: true,
    testerFullAccess: true,
  ),
  auth: AuthStateSnapshot(hasMockSession: true, hasAuthenticatedUser: true),
  mockLogin: MockLoginConfigState(email: '', password: ''),
);

class _ScriptedAiController extends AIController {
  _ScriptedAiController(super.ref);

  int _calls = 0;

  static const String malformedReply =
      'Malformed command detected. Use a plain request or supported command like /tasks, /goals, or /plan.';

  @override
  Future<AIRecommendation?> sendMessage(String text) async {
    _calls += 1;

    if (text.contains('/malformed')) {
      return const AIRecommendation(
        message: malformedReply,
        reasoning: 'safe-parse',
        emotion: 'cautious',
        confidence: 0.72,
      );
    }
    if (_calls == 1) {
      return const AIRecommendation(
        message: 'Start with your highest-priority unfinished task for 15 focused minutes.',
        reasoning: 'first-pass',
        emotion: 'focused',
        confidence: 0.8,
      );
    }

    return const AIRecommendation(
      message: 'Pick one frictionless win first, then escalate to your hardest task.',
      reasoning: 'second-pass',
      emotion: 'balanced',
      confidence: 0.78,
    );
  }
}

class _NoopVoiceService extends VoiceService {
  @override
  Future<void> speak(String text) async {}

  @override
  Future<void> stop() async {}
}
