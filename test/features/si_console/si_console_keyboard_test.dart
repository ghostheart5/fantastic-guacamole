import 'package:fantastic_guacamole/features/si_console/ui/si_console_screen.dart';
import 'package:fantastic_guacamole/state/controllers/ai_controller.dart';
import 'package:fantastic_guacamole/state/models/ai_recommendation.dart';
import 'package:fantastic_guacamole/state/controllers/voice_controller.dart';
import 'package:fantastic_guacamole/state/providers/intelligence_provider.dart';
import 'package:fantastic_guacamole/state/state/intelligence_state.dart';
import 'package:fantastic_guacamole/system/voice/voice_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'composer height reflects the real measured composer instead of a '
    'hardcoded 120/220 guess',
    (WidgetTester tester) async {
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
      await tester.pump();

      // Anchor on the composer's outer Container, identified by its
      // border-top decoration (unique to _InputBar): a KeyedSubtree-ancestor
      // search from the TextField or send icon over-matches, since
      // TextField/EditableText wrap themselves in framework-internal
      // KeyedSubtrees too.
      final Finder composerSubtree = find.byWidgetPredicate(
        (Widget widget) =>
            widget is Container &&
            widget.decoration ==
                const BoxDecoration(
                  color: Color(0xFF07111C),
                  border: Border(top: BorderSide(color: Colors.white24)),
                ),
      );
      expect(composerSubtree, findsOneWidget);
      final double actualHeight = tester.getSize(composerSubtree).height;

      final ValueListenableBuilder<double> builder = tester.widget(
        find.byType(ValueListenableBuilder<double>),
      );
      final double measuredHeight =
          (builder.valueListenable as ValueNotifier<double>).value;

      expect(measuredHeight, closeTo(actualHeight, 0.5));
      // The old guessed default (before the first frame measures the real
      // composer) was 220 regardless of what actually rendered.
      expect(measuredHeight, isNot(closeTo(220, 1)));
    },
  );

  testWidgets(
    'keyboard opening re-triggers a scroll back to the latest message',
    (WidgetTester tester) async {
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
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: SIConsoleScreen()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 60));

      // /help is a synchronous local shortcut (no AI dispatch) whose long
      // guide text is enough, repeated a few times, to overflow the
      // transcript viewport and make it scrollable.
      for (int i = 0; i < 6; i++) {
        await tester.enterText(
          find.byKey(const Key('si-query-input')),
          '/help',
        );
        await tester.tap(find.byIcon(Icons.send_rounded));
        await tester.pump();
      }

      final Finder transcript = find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      );
      final ScrollableState scrollable = tester.state<ScrollableState>(
        transcript,
      );
      // A lazy ListView's maxScrollExtent is an estimate over not-yet-built
      // children: adding 6 messages back to back can transiently spike the
      // estimate well past its true final value, which then triggers a
      // ballistic spring-back animation on the scroll position over several
      // frames. Poll until both settle instead of guessing a frame count.
      await _pumpUntilScrollSettled(tester, scrollable);
      expect(scrollable.position.maxScrollExtent, greaterThan(0));
      expect(scrollable.position.pixels, scrollable.position.maxScrollExtent);

      // Move the transcript directly. The Phase 7 query builder intentionally
      // overlaps the lower part of the transcript, so a center-point drag can
      // correctly hit the composer instead of the ListView.
      scrollable.position.jumpTo(
        (scrollable.position.maxScrollExtent - 300).clamp(
          0,
          scrollable.position.maxScrollExtent,
        ),
      );
      await tester.pump();
      expect(
        scrollable.position.pixels,
        lessThan(scrollable.position.maxScrollExtent),
      );

      // Simulate the keyboard opening. didChangeMetrics should re-anchor
      // the transcript to the latest message even though
      // resizeToAvoidBottomInset stays false. The animated background
      // repeats forever, so pumpAndSettle would never converge here.
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await _pumpUntilScrollSettled(tester, scrollable);

      expect(scrollable.position.pixels, scrollable.position.maxScrollExtent);
    },
  );
}

/// Pumps in small steps until [scrollable]'s pixels AND maxScrollExtent both
/// stop moving across a few consecutive frames (or [maxSteps] is hit as a
/// safety bound). Both must be tracked: a lazy ListView's maxScrollExtent
/// estimate can keep drifting for a while after a burst of new items, which
/// triggers a multi-frame ballistic spring-back on pixels once the estimate
/// corrects below the current (jumpTo'd) offset - watching pixels alone can
/// catch a momentary plateau mid-drift. Needed because SIConsoleScreen's
/// background runs an infinitely-repeating animation, so `pumpAndSettle`
/// can never be used here.
Future<void> _pumpUntilScrollSettled(
  WidgetTester tester,
  ScrollableState scrollable, {
  int maxSteps = 100,
}) async {
  double lastPixels = scrollable.position.pixels;
  double lastMax = scrollable.position.maxScrollExtent;
  int stableCount = 0;
  for (int i = 0; i < maxSteps; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    final double pixels = scrollable.position.pixels;
    final double maxExtent = scrollable.position.maxScrollExtent;
    if ((pixels - lastPixels).abs() < 0.5 &&
        (maxExtent - lastMax).abs() < 0.5) {
      stableCount += 1;
      if (stableCount >= 3) {
        return;
      }
    } else {
      stableCount = 0;
    }
    lastPixels = pixels;
    lastMax = maxExtent;
  }
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
  auth: AuthStateSnapshot(hasMockSignIn: true, hasAuthenticatedUser: false),
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
