import 'dart:async';

import 'package:fantastic_guacamole/domain/entities/planner_v2_response.dart';
import 'package:fantastic_guacamole/domain/release/assistant_release_control.dart';
import 'package:fantastic_guacamole/features/home/ui/smart_planner_screen.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/state/providers/memories_provider.dart';
import 'package:fantastic_guacamole/state/state/emotional_state.dart';
import 'package:fantastic_guacamole/system/voice/voice_service.dart';
import 'package:fantastic_guacamole/ui/widgets/error_boundary_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('TalkBack semantics and 200 percent text remain usable', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final SemanticsHandle semantics = tester.ensureSemantics();
    final ProviderContainer container = _container();
    addTearDown(container.dispose);
    try {
      await _pumpPlanner(tester, container, textScale: 2);

      expect(tester.takeException(), isNull);
      await _scrollTo(tester, find.text('CURRENT ENERGY'));
      expect(find.bySemanticsLabel(RegExp(r'Current energy')), findsOneWidget);
      await _scrollTo(tester, find.text('NEUTRAL'));
      expect(
        find.bySemanticsLabel(RegExp(r'^Select neutral emotional state')),
        findsOneWidget,
      );
      await _scrollTo(tester, find.byKey(const Key('planner-context-field')));
      expect(find.byKey(const Key('planner-context-field')), findsOneWidget);
      await _scrollTo(tester, find.text('GET GUIDANCE'));
      expect(find.bySemanticsLabel('GET GUIDANCE'), findsOneWidget);

      await _requestGuidance(tester);
      await _scrollTo(
        tester,
        find.bySemanticsLabel(RegExp(r'^Planning guidance ready')),
      );
      expect(
        find.bySemanticsLabel(RegExp(r'^Planning guidance ready')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('starts with an ephemeral input boundary and no write controls', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = _container();
    addTearDown(container.dispose);
    await _pumpPlanner(tester, container);

    await _scrollTo(tester, find.text('GET GUIDANCE'));
    expect(find.text('GET GUIDANCE'), findsOneWidget);
    expect(
      find.text(
        'Used only for this check-in. Nothing is saved unless you explicitly remember a preference.',
      ),
      findsOneWidget,
    );
    expect(find.text('PLANNING CONTEXT'), findsOneWidget);
    expect(find.textContaining('Check-in input stays ephemeral'), findsNothing);
    expect(
      find.textContaining('Used only for this check-in unless'),
      findsNothing,
    );
    final TextField contextField = tester.widget<TextField>(
      find.byKey(const Key('planner-context-field')),
    );
    expect(contextField.minLines, 3);
    expect(contextField.maxLines, 5);
    expect(contextField.style?.fontSize, 16);
    expect(contextField.decoration?.labelText, isNull);
    expect(
      contextField.decoration?.hintText,
      'What would you like help planning right now?',
    );
    expect(contextField.decoration?.contentPadding, const EdgeInsets.all(16));
    expect(find.text('Apply to Timeline'), findsNothing);
    expect(find.text('Preview Plan'), findsNothing);
    expect(find.text('Send a follow-up question...'), findsNothing);
  });

  testWidgets('release gate denial stays inline without global recovery', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = ProviderContainer(
      overrides: [
        smartPlannerQueryControllerProvider.overrideWith(
          _BlockedPlannerController.new,
        ),
        voiceServiceProvider.overrideWithValue(_NoopVoiceService()),
      ],
    );
    addTearDown(container.dispose);
    await _pumpPlanner(tester, container);

    await _requestGuidance(tester);

    expect(
      find.byKey(const Key('planner-guidance-unavailable')),
      findsOneWidget,
    );
    expect(find.byType(SmartPlannerScreen), findsOneWidget);
    expect(find.textContaining('Something went wrong'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders only the retained Planner V2 controls', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = _container();
    addTearDown(container.dispose);
    await _pumpPlanner(tester, container);
    await _requestGuidance(tester);

    await _scrollTo(tester, find.text('PLANNER V2'));
    expect(
      find.text('ON-DEVICE PLANNER V2 · DETERMINISTIC · NOT AI-GENERATED'),
      findsOneWidget,
    );
    expect(find.text('WHAT I HEARD'), findsNothing);
    expect(find.text('YOUR PLAN + TRADEOFF'), findsOneWidget);
    expect(find.text('ONE CONCRETE NEXT STEP'), findsOneWidget);
    expect(
      find.text('You want to move the release forward without hidden writes.'),
      findsNothing,
    );
    expect(find.text('Balanced release block'), findsOneWidget);
    expect(find.text('RECOMMENDED'), findsNothing);
    expect(find.textContaining('BEST-FIT · 20 MIN'), findsOneWidget);
    expect(find.text('Resolve and verify one release decision.'), findsNothing);
    expect(
      find.textContaining(
        'The selected capacity supports a bounded work block.',
      ),
      findsNothing,
    );
    expect(
      find.text('Tradeoff: Balanced effort and progress.'),
      findsOneWidget,
    );
    expect(
      find.text('Open the release note and write the unresolved decision.'),
      findsOneWidget,
    );
    expect(find.text('WHAT APPEARS TO MATTER MOST'), findsNothing);
    expect(find.text('VERIFIED CHRONOSPARK EVIDENCE'), findsNothing);
    expect(find.text('PLAN SPECTRUM'), findsNothing);
    expect(find.text('ONE USEFUL QUESTION'), findsNothing);
    expect(find.text('ADAPTATION RECEIPT'), findsNothing);
    expect(
      find.text('A bounded release decision with a reversible next step.'),
      findsNothing,
    );
    expect(find.text('Small release move'), findsNothing);
    expect(find.text('Deep release pass'), findsNothing);
    expect(find.text('What evidence will settle the decision?'), findsNothing);
    expect(find.textContaining('Inputs used: 70% energy'), findsNothing);
    expect(find.text('View alternatives and evidence'), findsNothing);
    expect(find.text('Try this'), findsNothing);
    expect(find.text('Edit'), findsNothing);
    expect(find.text('Make it smaller'), findsNothing);
    expect(find.text('Different approach'), findsNothing);
    expect(find.text('Why this?'), findsNothing);
    expect(find.text('Open as Creator draft'), findsNothing);
    expect(find.text('Remember a preference'), findsOneWidget);
    expect(find.text('Not now'), findsNothing);
    expect(find.text('READ ALOUD'), findsOneWidget);
    expect(find.text('VOICE INPUT'), findsOneWidget);
    expect(find.text('SPEAK'), findsNothing);
    expect(find.text('ON-DEVICE PLANNER · NOT AI-GENERATED'), findsNothing);
    expect(
      find.text('Guidance is advisory; you choose whether to apply it.'),
      findsNothing,
    );
    expect(tester.widget<Text>(find.text('PLANNER V2')).style?.fontSize, 13);
    expect(
      tester.widget<Text>(find.text('YOUR PLAN + TRADEOFF')).style?.fontSize,
      13,
    );
    expect(
      tester.widget<Text>(find.text('ONE CONCRETE NEXT STEP')).style?.fontSize,
      13,
    );
    expect(
      tester.widget<Text>(find.text('BEST-FIT · 20 MIN')).style?.fontSize,
      13,
    );
    expect(
      tester.widget<Text>(find.text('Balanced release block')).style?.fontSize,
      17,
    );
    expect(
      tester
          .widget<Text>(find.text('Tradeoff: Balanced effort and progress.'))
          .style
          ?.fontSize,
      16,
    );
    expect(
      tester
          .widget<Text>(
            find.text(
              'Open the release note and write the unresolved decision.',
            ),
          )
          .style
          ?.fontSize,
      16,
    );
  });

  testWidgets(
    'guidance reveals the response start instead of the page bottom',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final ProviderContainer container = _container();
      addTearDown(container.dispose);
      await _pumpPlanner(tester, container);

      await _requestGuidance(tester);
      await tester.pump(const Duration(milliseconds: 500));

      final Finder responseHeader = find.text('PLANNER V2');
      expect(responseHeader, findsOneWidget);
      final Rect headerRect = tester.getRect(responseHeader);
      expect(headerRect.top, greaterThanOrEqualTo(0));
      expect(headerRect.top, lessThan(300));
    },
  );

  testWidgets('read aloud is explicit and shows playback state', (
    WidgetTester tester,
  ) async {
    final _ControlledVoiceService voiceService = _ControlledVoiceService();
    final ProviderContainer container = _container(voiceService: voiceService);
    addTearDown(container.dispose);
    await _pumpPlanner(tester, container);

    await _requestGuidance(tester);
    expect(voiceService.speakCheckedCalls, 0);

    await _scrollTo(tester, find.text('READ ALOUD'));
    await tester.tap(find.text('READ ALOUD'));
    await tester.pump();

    expect(voiceService.speakCheckedCalls, 1);
    expect(find.text('READING'), findsOneWidget);
    expect(find.text('READ ALOUD'), findsNothing);

    voiceService.completePlayback(true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('READ ALOUD'), findsOneWidget);
    expect(find.text('READING'), findsNothing);
  });

  testWidgets('read aloud reports unavailable playback', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = _container(
      voiceService: _UnavailableVoiceService(),
    );
    addTearDown(container.dispose);
    await _pumpPlanner(tester, container);
    await _requestGuidance(tester);

    await _scrollTo(tester, find.text('READ ALOUD'));
    await tester.tap(find.text('READ ALOUD'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.text(
        'Audio is unavailable. Check text-to-speech settings and media volume.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('omits the duplicate progression and navigation footer', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = _container();
    addTearDown(container.dispose);
    await _pumpPlanner(tester, container);

    expect(find.text('OPEN CREATOR'), findsNothing);
    expect(find.text('GOALS'), findsNothing);
    expect(find.text('TIMELINE'), findsNothing);
    expect(find.textContaining('LVL '), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('durable memory defaults to use-once and requires consent', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = _container();
    addTearDown(container.dispose);
    await _pumpPlanner(tester, container);
    await _requestGuidance(tester);

    final Finder remember = find.byKey(
      const Key('planner-remember-preference'),
    );
    await _scrollTo(tester, remember);
    await tester.tap(remember);
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Use only this time'), findsOneWidget);
    expect(find.textContaining('Receipt preview'), findsOneWidget);
    final Finder confirm = find.byKey(const Key('planner-confirm-memory'));
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);

    await tester.enterText(
      find.byKey(const Key('planner-memory-preference-field')),
      'Prefer one small next step.',
    );
    tester
        .widget<CheckboxListTile>(
          find.byKey(const Key('planner-memory-consent')),
        )
        .onChanged!(true);
    await tester.pump();
    expect(tester.widget<FilledButton>(confirm).onPressed, isNotNull);

    await tester.tap(find.text('Use only this time'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(container.read(memoriesProvider), isEmpty);
    expect(find.textContaining('No durable memory was saved'), findsOneWidget);
  });
}

ProviderContainer _container({VoiceService? voiceService}) {
  return ProviderContainer(
    overrides: [
      smartPlannerQueryControllerProvider.overrideWith(
        _PlannerV2TestController.new,
      ),
      voiceServiceProvider.overrideWithValue(
        voiceService ?? _NoopVoiceService(),
      ),
    ],
  );
}

Future<void> _pumpPlanner(
  WidgetTester tester,
  ProviderContainer container, {
  double textScale = 1,
}) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: const ErrorBoundary(child: SmartPlannerScreen()),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _requestGuidance(WidgetTester tester) async {
  await _scrollTo(tester, find.text('GET GUIDANCE'));
  await tester.tap(find.text('GET GUIDANCE'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    350,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(finder);
  await tester.pump();
}

class _PlannerV2TestController extends SmartPlannerQueryController {
  _PlannerV2TestController(super.ref);

  @override
  bool detectsCrisis(String text) => false;

  @override
  Future<SmartPlannerResult> requestPlanningGuidance({
    required double energy,
    required EmotionalState emotion,
    required String notes,
    required List<Map<String, String>> history,
    required String? previousSavedNotes,
  }) async {
    final PlannerV2Response response = _testResponse();
    return SmartPlannerResult(
      prompt: notes.isEmpty ? 'Plan my next move' : notes,
      message: response.toAccessibleText(),
      savedNotes: null,
      evidence: response.verifiedEvidence,
      plannerResponse: response,
    );
  }

  @override
  Future<String> requestFollowUp({
    required String input,
    required double energy,
    required EmotionalState emotion,
    required String reflection,
    required List<Map<String, String>> history,
  }) async => 'Follow-up response for $input';
}

class _BlockedPlannerController extends SmartPlannerQueryController {
  _BlockedPlannerController(super.ref);

  @override
  bool detectsCrisis(String text) => false;

  @override
  Future<SmartPlannerResult> requestPlanningGuidance({
    required double energy,
    required EmotionalState emotion,
    required String notes,
    required List<Map<String, String>> history,
    required String? previousSavedNotes,
  }) async {
    final AssistantReleaseDecision decision = const AssistantReleaseController()
        .decide(
          config: AssistantReleaseConfig(
            stage: AssistantReleaseStage.off,
            canaryBasisPoints: 0,
            shadowEvaluationEnabled: false,
            internalAccountDigests: const <String>{},
            rollbackCapabilities: const <AssistantReleaseCapability>{},
          ),
          request: const AssistantReleaseRequest(
            accountScopeId: 'account.test',
            capability: AssistantReleaseCapability.smartPlannerV2,
            betaOptIn: false,
          ),
        );
    throw AssistantReleaseBlockedException(decision);
  }
}

PlannerV2Response _testResponse() {
  return PlannerV2Response(
    whatIHeard: 'You want to move the release forward without hidden writes.',
    mattersMost: 'A bounded release decision with a reversible next step.',
    verifiedEvidence: const <String>[
      'Current check-in energy set by you: 70%.',
      'Current check-in emotional state selected by you: neutral.',
      'No ChronoSpark domain record was changed.',
    ],
    options: const <PlannerOption>[
      PlannerOption(
        kind: PlannerOptionKind.minimum,
        title: 'Small release move',
        description: 'Write the next release decision.',
        estimatedMinutes: 5,
        tradeoff: 'Fast but narrow.',
      ),
      PlannerOption(
        kind: PlannerOptionKind.bestFit,
        title: 'Balanced release block',
        description: 'Resolve and verify one release decision.',
        estimatedMinutes: 20,
        tradeoff: 'Balanced effort and progress.',
      ),
      PlannerOption(
        kind: PlannerOptionKind.stretch,
        title: 'Deep release pass',
        description: 'Resolve, verify, and document two decisions.',
        estimatedMinutes: 40,
        tradeoff: 'Higher attention cost.',
      ),
    ],
    recommendedKind: PlannerOptionKind.bestFit,
    recommendationReason:
        'The selected capacity supports a bounded work block.',
    nextStep: 'Open the release note and write the unresolved decision.',
    usefulQuestion: 'What evidence will settle the decision?',
    adaptationReceipt: PlannerAdaptationReceipt(
      userSetEnergy: 0.7,
      userSelectedEmotion: EmotionalState.neutral,
      adjustments: const <String>[
        'Scaled options from 5 to 40 minutes.',
        'No emotion was inferred.',
      ],
    ),
    origin: PlannerResponseOrigin.deterministic,
  );
}

class _NoopVoiceService extends VoiceService {
  @override
  Future<void> speak(String text) async {}

  @override
  Future<void> stop() async {}
}

class _ControlledVoiceService extends VoiceService {
  final Completer<bool> _playback = Completer<bool>();
  int speakCheckedCalls = 0;

  @override
  Future<bool> speakChecked(String text) {
    speakCheckedCalls += 1;
    return _playback.future;
  }

  void completePlayback(bool result) {
    _playback.complete(result);
  }

  @override
  Future<void> stop() async {}
}

class _UnavailableVoiceService extends VoiceService {
  @override
  Future<bool> speakChecked(String text) async => false;

  @override
  Future<void> stop() async {}
}
