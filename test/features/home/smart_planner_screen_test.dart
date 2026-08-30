import 'dart:async';

import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/domain/entities/planner_v2_response.dart';
import 'package:fantastic_guacamole/domain/entities/decision_outcome_entity.dart';
import 'package:fantastic_guacamole/domain/operating_system/operating_system_contract.dart';
import 'package:fantastic_guacamole/domain/release/assistant_release_control.dart';
import 'package:fantastic_guacamole/features/home/ui/smart_planner_screen.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/state/providers/memories_provider.dart';
import 'package:fantastic_guacamole/state/providers/smart_planner_first_value_provider.dart';
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
        'Your words and check-in stay ephemeral. A local decision receipt may record which guidance was shown or used. Nothing else is saved unless you explicitly remember a preference.',
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

  testWidgets('staged first value applies context and generates guidance', (
    WidgetTester tester,
  ) async {
    final AccountStorageScope scope = AccountStorageScope.authenticated(
      'first-value-account',
    );
    final ProviderContainer container = _container(accountScope: scope);
    addTearDown(container.dispose);
    container
        .read(smartPlannerFirstValueProvider.notifier)
        .stage(
          SmartPlannerFirstValueRequest(
            accountScopeId: scope.v2Namespace!,
            prompt: 'Help me choose one bounded launch-readiness step.',
            energy: 0.35,
            createdAt: DateTime.now().toUtc(),
          ),
        );

    await _pumpPlanner(tester, container);

    final _PlannerV2TestController planner =
        container.read(smartPlannerQueryControllerProvider)
            as _PlannerV2TestController;
    expect(planner.guidanceRequestCount, 1);
    expect(
      planner.lastNotes,
      'Help me choose one bounded launch-readiness step.',
    );
    expect(planner.lastEnergy, 0.35);
    expect(container.read(smartPlannerFirstValueProvider), isNull);
    expect(container.read(memoriesProvider), isEmpty);
    await _scrollTo(tester, find.text('PLANNER V2'));
    expect(
      find.text('ON-DEVICE PLANNER V2 · DETERMINISTIC · NOT AI-GENERATED'),
      findsOneWidget,
    );
  });

  testWidgets('rebuild does not duplicate staged first-value guidance', (
    WidgetTester tester,
  ) async {
    final AccountStorageScope scope = AccountStorageScope.authenticated(
      'first-value-rebuild-account',
    );
    final ProviderContainer container = _container(accountScope: scope);
    addTearDown(container.dispose);
    container
        .read(smartPlannerFirstValueProvider.notifier)
        .stage(
          SmartPlannerFirstValueRequest(
            accountScopeId: scope.v2Namespace!,
            prompt: 'Give me one useful choice.',
            createdAt: DateTime.now().toUtc(),
          ),
        );

    await _pumpPlanner(tester, container);
    final _PlannerV2TestController planner =
        container.read(smartPlannerQueryControllerProvider)
            as _PlannerV2TestController;
    expect(planner.guidanceRequestCount, 1);

    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(planner.guidanceRequestCount, 1);
    expect(container.read(smartPlannerFirstValueProvider), isNull);
  });

  testWidgets(
    'delayed auto first value shows progress and completes exactly once',
    (WidgetTester tester) async {
      final AccountStorageScope scope = AccountStorageScope.authenticated(
        'first-value-delayed-account',
      );
      final ProviderContainer container = _container(
        accountScope: scope,
        plannerBuilder: _DelayedPlannerController.new,
      );
      addTearDown(container.dispose);
      container
          .read(smartPlannerFirstValueProvider.notifier)
          .stage(
            SmartPlannerFirstValueRequest(
              accountScopeId: scope.v2Namespace!,
              prompt: 'Hold this request until guidance is ready.',
              energy: 0.5,
              createdAt: DateTime.now().toUtc(),
            ),
          );

      await _pumpPlanner(tester, container);
      final _DelayedPlannerController planner =
          container.read(smartPlannerQueryControllerProvider)
              as _DelayedPlannerController;
      expect(planner.guidanceRequestCount, 1);
      expect(container.read(smartPlannerFirstValueProvider), isNull);
      await _scrollTo(tester, find.text('THINKING...'));
      expect(find.text('THINKING...'), findsOneWidget);

      await tester.binding.setSurfaceSize(const Size(420, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pump();
      expect(planner.guidanceRequestCount, 1);

      planner.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(planner.guidanceRequestCount, 1);
      await _scrollTo(tester, find.text('PLANNER V2'));
      expect(
        find.text('ON-DEVICE PLANNER V2 · DETERMINISTIC · NOT AI-GENERATED'),
        findsOneWidget,
      );
    },
  );

  testWidgets('auto-consumed blocked request stays inline for retry', (
    WidgetTester tester,
  ) async {
    final AccountStorageScope scope = AccountStorageScope.authenticated(
      'first-value-blocked-account',
    );
    final ProviderContainer container = _container(
      accountScope: scope,
      plannerBuilder: _BlockedPlannerController.new,
    );
    addTearDown(container.dispose);
    const String prompt = 'Keep this blocked request available for retry.';
    container
        .read(smartPlannerFirstValueProvider.notifier)
        .stage(
          SmartPlannerFirstValueRequest(
            accountScopeId: scope.v2Namespace!,
            prompt: prompt,
            createdAt: DateTime.now().toUtc(),
          ),
        );

    await _pumpPlanner(tester, container);
    final _BlockedPlannerController planner =
        container.read(smartPlannerQueryControllerProvider)
            as _BlockedPlannerController;
    expect(planner.guidanceRequestCount, 1);
    await _expectInlineFirstValueRetry(tester, prompt);
  });

  testWidgets('auto-consumed error request stays inline for retry', (
    WidgetTester tester,
  ) async {
    final AccountStorageScope scope = AccountStorageScope.authenticated(
      'first-value-error-account',
    );
    final ProviderContainer container = _container(
      accountScope: scope,
      plannerBuilder: _FailingPlannerController.new,
    );
    addTearDown(container.dispose);
    const String prompt = 'Keep this failed request available for retry.';
    container
        .read(smartPlannerFirstValueProvider.notifier)
        .stage(
          SmartPlannerFirstValueRequest(
            accountScopeId: scope.v2Namespace!,
            prompt: prompt,
            energy: 0.2,
            createdAt: DateTime.now().toUtc(),
          ),
        );

    await _pumpPlanner(tester, container);
    final _FailingPlannerController planner =
        container.read(smartPlannerQueryControllerProvider)
            as _FailingPlannerController;
    expect(planner.guidanceRequestCount, 1);
    await _expectInlineFirstValueRetry(tester, prompt);
    expect(find.text(_plannerRetryMessageForTest), findsOneWidget);
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

  testWidgets('renders the calm Planner V2 action set', (
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
    expect(find.text('Use this plan'), findsOneWidget);
    expect(find.text('Make smaller'), findsOneWidget);
    expect(find.text('Different approach'), findsOneWidget);
    expect(find.text('Why this'), findsOneWidget);
    expect(find.text('Evidence'), findsOneWidget);
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

  testWidgets('records canonical receipt outcomes and stages Creator preview', (
    WidgetTester tester,
  ) async {
    final List<DecisionOutcomeKind> outcomes = <DecisionOutcomeKind>[];
    final ProviderContainer container = _container(
      operatingReceipt: _screenOperatingReceipt(),
      outcomes: outcomes,
    );
    addTearDown(container.dispose);
    await _pumpPlanner(tester, container);
    await _requestGuidance(tester);
    await tester.pump();

    expect(outcomes, <DecisionOutcomeKind>[DecisionOutcomeKind.shown]);

    await _scrollTo(tester, find.text('Make smaller'));
    await tester.tap(find.text('Make smaller'));
    await tester.pump();
    expect(outcomes.last, DecisionOutcomeKind.deferred);

    await _scrollTo(tester, find.text('Different approach'));
    await tester.tap(find.text('Different approach'));
    await tester.pump();
    expect(outcomes.last, DecisionOutcomeKind.rejected);

    await _scrollTo(tester, find.text('Use this plan'));
    await tester.tap(find.text('Use this plan'));
    await tester.pump();

    expect(outcomes.last, DecisionOutcomeKind.accepted);
    expect(
      outcomes.where(
        (DecisionOutcomeKind kind) => kind == DecisionOutcomeKind.shown,
      ),
      hasLength(1),
    );
    expect(container.read(creatorDraftPreviewProvider), isNotNull);
    expect(container.read(appFlowProvider), AppView.creator);
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

ProviderContainer _container({
  VoiceService? voiceService,
  OperatingDecisionReceipt? operatingReceipt,
  List<DecisionOutcomeKind>? outcomes,
  AccountStorageScope? accountScope,
  SmartPlannerQueryController Function(Ref)? plannerBuilder,
}) {
  return ProviderContainer(
    overrides: [
      smartPlannerQueryControllerProvider.overrideWith(
        plannerBuilder ?? _PlannerV2TestController.new,
      ),
      voiceServiceProvider.overrideWithValue(
        voiceService ?? _NoopVoiceService(),
      ),
      smartPlannerOperatingReceiptProvider.overrideWithValue(operatingReceipt),
      decisionOutcomeActionsProvider.overrideWith(
        (Ref ref) => _RecordingDecisionOutcomeActions(
          ref,
          outcomes ?? <DecisionOutcomeKind>[],
        ),
      ),
      if (accountScope != null)
        accountStorageScopeProvider.overrideWithValue(accountScope),
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

const String _plannerRetryMessageForTest =
    'Guidance could not be generated. Your check-in is still here. Tap GET GUIDANCE to retry.';

Future<void> _expectInlineFirstValueRetry(
  WidgetTester tester,
  String prompt,
) async {
  await _scrollTo(
    tester,
    find.byKey(const Key('planner-guidance-unavailable')),
  );
  expect(find.byKey(const Key('planner-guidance-unavailable')), findsOneWidget);
  expect(find.byType(SmartPlannerScreen), findsOneWidget);
  expect(find.textContaining('Something went wrong'), findsNothing);

  await _scrollTo(tester, find.byKey(const Key('planner-context-field')));
  final TextField contextField = tester.widget<TextField>(
    find.byKey(const Key('planner-context-field')),
  );
  expect(contextField.controller?.text, prompt);
  await _scrollTo(tester, find.text('GET GUIDANCE'));
  expect(find.text('GET GUIDANCE'), findsOneWidget);
  expect(tester.takeException(), isNull);
}

class _PlannerV2TestController extends SmartPlannerQueryController {
  _PlannerV2TestController(super.ref) : _testRef = ref;

  final Ref _testRef;
  int guidanceRequestCount = 0;
  double? lastEnergy;
  String? lastNotes;

  @override
  bool detectsCrisis(String text) => false;

  @override
  Future<SmartPlannerResult> requestPlanningGuidance({
    required double? energy,
    required EmotionalState? emotion,
    required String notes,
    required List<Map<String, String>> history,
    required String? previousSavedNotes,
  }) async {
    guidanceRequestCount += 1;
    lastEnergy = energy;
    lastNotes = notes;
    return _testPlannerResult(_testRef, notes);
  }

  @override
  Future<String> requestFollowUp({
    required String input,
    required double? energy,
    required EmotionalState? emotion,
    required String reflection,
    required List<Map<String, String>> history,
  }) async => 'Follow-up response for $input';
}

class _DelayedPlannerController extends _PlannerV2TestController {
  _DelayedPlannerController(super.ref);

  final Completer<void> _release = Completer<void>();

  @override
  Future<SmartPlannerResult> requestPlanningGuidance({
    required double? energy,
    required EmotionalState? emotion,
    required String notes,
    required List<Map<String, String>> history,
    required String? previousSavedNotes,
  }) async {
    guidanceRequestCount += 1;
    lastEnergy = energy;
    lastNotes = notes;
    await _release.future;
    return _testPlannerResult(_testRef, notes);
  }

  void complete() => _release.complete();
}

class _BlockedPlannerController extends SmartPlannerQueryController {
  _BlockedPlannerController(super.ref);

  int guidanceRequestCount = 0;

  @override
  bool detectsCrisis(String text) => false;

  @override
  Future<SmartPlannerResult> requestPlanningGuidance({
    required double? energy,
    required EmotionalState? emotion,
    required String notes,
    required List<Map<String, String>> history,
    required String? previousSavedNotes,
  }) async {
    guidanceRequestCount += 1;
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

class _FailingPlannerController extends SmartPlannerQueryController {
  _FailingPlannerController(super.ref);

  int guidanceRequestCount = 0;

  @override
  bool detectsCrisis(String text) => false;

  @override
  Future<SmartPlannerResult> requestPlanningGuidance({
    required double? energy,
    required EmotionalState? emotion,
    required String notes,
    required List<Map<String, String>> history,
    required String? previousSavedNotes,
  }) async {
    guidanceRequestCount += 1;
    throw StateError('simulated planner failure');
  }
}

SmartPlannerResult _testPlannerResult(Ref ref, String notes) {
  final PlannerV2Response response = _testResponse();
  return SmartPlannerResult(
    prompt: notes.isEmpty ? 'Plan my next move' : notes,
    message: response.toAccessibleText(),
    savedNotes: null,
    evidence: response.verifiedEvidence,
    plannerResponse: response,
    operatingReceipt: ref.read(smartPlannerOperatingReceiptProvider),
  );
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

OperatingDecisionReceipt _screenOperatingReceipt() => OperatingDecisionReceipt(
  decisionId: 'screen-receipt',
  subjectId: null,
  recommendedAction: 'Prepare release evidence',
  rationale: 'The release evidence matches the current Planner request.',
  whyItMatters: 'The release gate needs one verified decision.',
  consequenceOfDelay: 'The release gate remains unresolved.',
  generatedAt: DateTime.utc(2026, 8, 30, 10),
  expiresAt: DateTime.utc(2026, 9, 1, 10),
  confidence: OperatingConfidence.moderate,
  evidence: <OperatingEvidence>[
    OperatingEvidence(
      code: 'release-evidence',
      description: 'Release evidence is incomplete.',
      kind: OperatingEvidenceKind.observed,
      recordedAt: DateTime.utc(2026, 8, 30, 10),
      source: 'local_release_gate',
    ),
  ],
  actionIntent: const OperatingActionIntent(
    id: 'creator-review',
    type: OperatingActionType.openCreator,
    label: 'Review in Creator',
    destination: 'creator',
    requiresConfirmation: true,
  ),
  sourceRevisions: const <String, String>{'release': 'r1'},
  modelVersion: 'screen-receipt-v1',
);

class _RecordingDecisionOutcomeActions extends DecisionOutcomeActions {
  _RecordingDecisionOutcomeActions(super.ref, this.outcomes);

  final List<DecisionOutcomeKind> outcomes;

  @override
  Future<void> record({
    required OperatingDecisionReceipt receipt,
    required DecisionOutcomeKind kind,
    required String surface,
    String? detail,
  }) async {
    expect(receipt.decisionId, 'screen-receipt');
    expect(surface, 'smart_planner');
    outcomes.add(kind);
  }
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
