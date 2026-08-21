import 'package:fantastic_guacamole/domain/entities/planner_v2_response.dart';
import 'package:fantastic_guacamole/features/home/ui/smart_planner_screen.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/state/state/emotional_state.dart';
import 'package:fantastic_guacamole/system/voice/voice_service.dart';
import 'package:fantastic_guacamole/ui/widgets/error_boundary_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('starts with an ephemeral input boundary and no write controls', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = _container();
    addTearDown(container.dispose);
    await _pumpPlanner(tester, container);

    await _scrollTo(tester, find.text('GET GUIDANCE'));
    expect(find.text('GET GUIDANCE'), findsOneWidget);
    expect(
      find.textContaining('Check-in input stays ephemeral'),
      findsOneWidget,
    );
    expect(find.text('Apply to Timeline'), findsNothing);
    expect(find.text('Preview Plan'), findsNothing);
    expect(find.text('Send a follow-up question...'), findsNothing);
  });

  testWidgets('renders the full Planner V2 contract and honest provenance', (
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
    expect(find.text('WHAT I HEARD · EDITABLE'), findsOneWidget);
    expect(find.text('WHAT APPEARS TO MATTER MOST'), findsOneWidget);
    expect(find.text('VERIFIED CHRONOSPARK EVIDENCE'), findsOneWidget);
    expect(find.text('PLAN SPECTRUM'), findsOneWidget);
    expect(find.text('RECOMMENDED OPTION + TRADEOFF'), findsOneWidget);
    expect(find.text('ONE CONCRETE NEXT STEP'), findsOneWidget);
    expect(find.text('ONE USEFUL QUESTION'), findsOneWidget);
    expect(find.text('ADAPTATION RECEIPT'), findsOneWidget);
    expect(find.textContaining('MINIMUM · 5 MIN'), findsOneWidget);
    expect(find.textContaining('BEST-FIT · 20 MIN'), findsOneWidget);
    expect(find.textContaining('STRETCH · 40 MIN'), findsOneWidget);
    expect(find.text('Try this'), findsOneWidget);
    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Make it smaller'), findsOneWidget);
    expect(find.text('Different approach'), findsOneWidget);
    expect(find.text('Why this?'), findsOneWidget);
    expect(find.text('Open as Creator draft'), findsOneWidget);
    expect(find.text('Not now'), findsOneWidget);
  });

  testWidgets('What I heard can be edited without creating saved state', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = _container();
    addTearDown(container.dispose);
    await _pumpPlanner(tester, container);
    await _requestGuidance(tester);

    await _scrollTo(tester, find.text('Edit'));
    await tester.tap(find.text('Edit'));
    await tester.pump();
    final Finder field = find.byKey(const Key('planner-what-i-heard-field'));
    expect(field, findsOneWidget);
    await tester.enterText(field, 'I want to finish one release decision.');
    final Finder saveButton = find.widgetWithText(
      ElevatedButton,
      'Save check-in edit',
    );
    tester.widget<ElevatedButton>(saveButton).onPressed!();
    await tester.pump();

    expect(find.text('I want to finish one release decision.'), findsOneWidget);
    expect(
      find.textContaining('Understanding updated for this check-in only'),
      findsOneWidget,
    );
  });

  testWidgets('Make it smaller changes only the local recommendation', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = _container();
    addTearDown(container.dispose);
    await _pumpPlanner(tester, container);
    await _requestGuidance(tester);

    await _scrollTo(tester, find.text('Make it smaller'));
    await tester.tap(find.text('Make it smaller'));
    await tester.pump();

    expect(
      find.textContaining('Recommendation reduced locally. Nothing was saved.'),
      findsOneWidget,
    );
    expect(find.text('Small release move'), findsNWidgets(2));
  });

  testWidgets('Open as Creator draft creates only a transient preview', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = _container();
    addTearDown(container.dispose);
    await _pumpPlanner(tester, container);
    await _requestGuidance(tester);

    final Finder control = find.byKey(const Key('planner-open-creator-draft'));
    await _scrollTo(tester, control);
    await tester.tap(control);
    await tester.pump();

    final CreatorDraftPreview? draft = container.read(
      creatorDraftPreviewProvider,
    );
    expect(draft, isNotNull);
    expect(draft!.title, 'Balanced release block');
    expect(draft.sourceOption, PlannerOptionKind.bestFit);
    expect(container.read(appFlowProvider), AppView.creator);
  });

  testWidgets('Not now dismisses the response without applying anything', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = _container();
    addTearDown(container.dispose);
    await _pumpPlanner(tester, container);
    await _requestGuidance(tester);

    await _scrollTo(tester, find.text('Not now'));
    await tester.tap(find.text('Not now'));
    await tester.pump();

    expect(find.text('PLANNER V2'), findsNothing);
    expect(container.read(creatorDraftPreviewProvider), isNull);
    expect(find.text('Apply to Timeline'), findsNothing);
  });
}

ProviderContainer _container() {
  return ProviderContainer(
    overrides: [
      smartPlannerQueryControllerProvider.overrideWith(
        _PlannerV2TestController.new,
      ),
      voiceServiceProvider.overrideWithValue(_NoopVoiceService()),
    ],
  );
}

Future<void> _pumpPlanner(
  WidgetTester tester,
  ProviderContainer container,
) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: ErrorBoundary(child: SmartPlannerScreen()),
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
