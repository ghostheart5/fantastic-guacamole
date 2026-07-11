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

void main() {
  testWidgets('malformed empty input is ignored without dispatching AI call', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = ProviderContainer(
      overrides: [
        aiControllerProvider.overrideWith(
          (Ref ref) => _RecordingAiController(ref),
        ),
        voiceServiceProvider.overrideWithValue(_NoopVoiceService()),
        intelligenceStateProvider.overrideWithValue(_intelligence),
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
    await tester.pump(const Duration(milliseconds: 60));

    await tester.enterText(find.byType(TextField), '    ');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();

    final _RecordingAiController controller =
        container.read(aiControllerProvider) as _RecordingAiController;
    expect(controller.calls, 0);
    expect(
      find.textContaining('No grounded response was generated'),
      findsNothing,
    );
  });

  testWidgets('invalid input result displays safe fallback response', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = ProviderContainer(
      overrides: [
        aiControllerProvider.overrideWith((Ref ref) => _NullAiController(ref)),
        voiceServiceProvider.overrideWithValue(_NoopVoiceService()),
        intelligenceStateProvider.overrideWithValue(_intelligence),
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
    await tester.pump(const Duration(milliseconds: 60));

    await tester.enterText(
      find.byType(TextField),
      'show unknown malformed module',
    );
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));

    expect(
      find.textContaining('No grounded response was generated'),
      findsOneWidget,
    );
  });

  testWidgets('AI errors still render safe SI fallback response', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = ProviderContainer(
      overrides: [
        aiControllerProvider.overrideWith((Ref ref) => _ErrorAiController(ref)),
        voiceServiceProvider.overrideWithValue(_NoopVoiceService()),
        intelligenceStateProvider.overrideWithValue(_intelligence),
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
    await tester.pump(const Duration(milliseconds: 60));

    await tester.enterText(find.byType(TextField), 'summarize my trajectory');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.textContaining('Full intelligence context lock failed'),
      findsOneWidget,
    );
  });
}

const IntelligenceState _intelligence = IntelligenceState(
  environment: EnvironmentState(
    appName: 'ChronoSpark',
    appFlavor: 'dev',
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
  auth: AuthStateSnapshot(hasMockSession: true, hasAuthenticatedUser: false),
  mockLogin: MockLoginConfigState(email: '', password: ''),
);

class _RecordingAiController extends AIController {
  _RecordingAiController(super.ref);

  int calls = 0;

  @override
  Future<AIRecommendation?> sendMessage(String text) async {
    calls += 1;
    return const AIRecommendation(
      message: 'ok',
      reasoning: 'n/a',
      emotion: 'balanced',
      confidence: 1,
    );
  }
}

class _NoopVoiceService extends VoiceService {
  @override
  Future<void> speak(String text) async {}

  @override
  Future<void> stop() async {}
}

class _NullAiController extends AIController {
  _NullAiController(super.ref);

  @override
  Future<AIRecommendation?> sendMessage(String text) async {
    return null;
  }
}

class _ErrorAiController extends AIController {
  _ErrorAiController(super.ref);

  @override
  Future<AIRecommendation?> sendMessage(String text) async {
    throw StateError('simulated non-exception AI failure');
  }
}
