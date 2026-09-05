import 'dart:async';

import 'package:fantastic_guacamole/core/storage/account_storage_namespace.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/services/ai/planner_explanation_service.dart';
import 'package:fantastic_guacamole/state/providers/storage_providers.dart';
import 'package:fantastic_guacamole/data/repositories/person_context_repository.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/domain/entities/planner_explanation_contract.dart';
import 'package:fantastic_guacamole/domain/entities/person_context.dart';
import 'package:fantastic_guacamole/domain/entities/planner_v2_response.dart';
import 'package:fantastic_guacamole/domain/entities/decision_outcome_entity.dart';
import 'package:fantastic_guacamole/domain/policies/person_context_behavior_policy.dart';
import 'package:fantastic_guacamole/domain/operating_system/operating_system_contract.dart';
import 'package:fantastic_guacamole/domain/release/assistant_release_control.dart';
import 'package:fantastic_guacamole/features/home/ui/smart_planner_screen.dart';
import 'package:fantastic_guacamole/l10n/chronospark_localizations.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/state/providers/assistant_release_provider.dart';
import 'package:fantastic_guacamole/state/providers/memories_provider.dart';
import 'package:fantastic_guacamole/state/providers/planner_explanation_provider.dart';
import 'package:fantastic_guacamole/state/providers/smart_planner_first_value_provider.dart';
import 'package:fantastic_guacamole/state/state/emotional_state.dart';
import 'package:fantastic_guacamole/system/voice/voice_service.dart';
import 'package:fantastic_guacamole/ui/widgets/error_boundary_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() {
  testWidgets(
    'Spanish distress input pauses before Planner intelligence executes',
    (WidgetTester tester) async {
      late _PlannerV2TestController planner;
      final ProviderContainer container = _container(
        plannerBuilder: (Ref ref) => planner = _PlannerV2TestController(ref),
      );
      addTearDown(container.dispose);
      await _pumpPlanner(tester, container, locale: const Locale('es'));

      await _scrollTo(tester, find.byKey(const Key('planner-context-field')));
      await tester.enterText(
        find.byKey(const Key('planner-context-field')),
        'Tengo un ataque de panico.',
      );
      await _requestGuidance(tester);

      expect(
        find.byKey(const Key('supportive-distress-dialog')),
        findsOneWidget,
      );
      expect(find.text('¿Qué apoyo te ayudaría ahora?'), findsOneWidget);
      expect(planner.guidanceRequestCount, 0);
    },
  );

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

  testWidgets(
    'first useful decision offers narrow context and saves only after consent',
    (WidgetTester tester) async {
      final AccountStorageScope scope = AccountStorageScope.authenticated(
        'first-context-account',
      );
      final _MemoryPrefs store = _MemoryPrefs();
      final PersonContextRepository repository = PersonContextRepository(
        store,
        scope,
      );
      final ProviderContainer container = _container(
        accountScope: scope,
        sharedPrefsStore: store,
        personContextRepository: repository,
        firstUseContextOfferSeen: false,
      );
      addTearDown(container.dispose);
      await _pumpPlanner(tester, container);
      await _scrollTo(tester, find.byKey(const Key('planner-context-field')));
      await tester.enterText(
        find.byKey(const Key('planner-context-field')),
        'Prepare the closed-test release safely.',
      );
      await _requestGuidance(tester);
      await _scrollTo(tester, find.byKey(const Key('first-use-context-offer')));

      expect(find.byKey(const Key('first-use-context-offer')), findsOneWidget);
      expect(find.textContaining('decision support'), findsOneWidget);
      expect(find.textContaining('Smart Planner only'), findsOneWidget);
      expect(find.textContaining('expiry · 30 days'), findsOneWidget);
      expect((await repository.load()).signals, isEmpty);

      await tester.tap(find.byKey(const Key('first-use-context-add')));
      await tester.pump();
      expect(find.text('Save your current priority?'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('first-use-context-confirm')),
            )
            .onPressed,
        isNull,
      );
      await tester.enterText(
        find.byKey(const Key('first-use-context-value')),
        'Closed-test readiness comes first.',
      );
      await tester.tap(find.byKey(const Key('first-use-context-consent')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('first-use-context-confirm')));
      await tester.pump(const Duration(milliseconds: 300));

      final signal = (await repository.load()).signals.single;
      expect(signal.value, 'Closed-test readiness comes first.');
      expect(signal.surfaceScopes, {PersonContextSurface.smartPlanner});
      expect(signal.purpose, PersonContextPurpose.decisionSupport);
      expect(signal.expiresAt.difference(signal.recordedAt).inDays, 30);
      expect(
        signal.deletionBehavior,
        PersonContextDeletionBehavior.expiresAutomatically,
      );
      final PersonContextBehaviorTrace eligibility =
          PersonContextBehaviorPolicy.evaluate(
            signals: <PersonContextSignal>[signal],
            surface: PersonContextSurface.smartPlanner,
            purposes: const <PersonContextPurpose>{
              PersonContextPurpose.decisionSupport,
            },
            relevance: <String, PersonContextRelevanceBasis>{
              signal.id: PersonContextRelevanceBasis.typedActivePlanningWindow,
            },
            now: signal.recordedAt.add(const Duration(minutes: 1)),
            noContextBaseline: const <PersonContextBehaviorField, Object?>{},
          );
      expect(eligibility.used.single.signalId, signal.id);
      expect(eligibility.rejected, isEmpty);
    },
  );

  testWidgets(
    'declining optional context saves nothing and requests no retry',
    (WidgetTester tester) async {
      final AccountStorageScope scope = AccountStorageScope.authenticated(
        'decline-context-account',
      );
      final _MemoryPrefs store = _MemoryPrefs();
      final PersonContextRepository repository = PersonContextRepository(
        store,
        scope,
      );
      final ProviderContainer container = _container(
        accountScope: scope,
        sharedPrefsStore: store,
        personContextRepository: repository,
        firstUseContextOfferSeen: false,
      );
      addTearDown(container.dispose);
      await _pumpPlanner(tester, container);
      await _scrollTo(tester, find.byKey(const Key('planner-context-field')));
      await tester.enterText(
        find.byKey(const Key('planner-context-field')),
        'Prepare the closed-test release safely.',
      );
      await _requestGuidance(tester);

      final Finder dismiss = find.byKey(const Key('first-use-context-dismiss'));
      await _scrollTo(tester, dismiss);
      await tester.tap(dismiss);
      await tester.pump();

      expect(find.byKey(const Key('first-use-context-offer')), findsNothing);
      final _PlannerV2TestController planner =
          container.read(smartPlannerQueryControllerProvider)
              as _PlannerV2TestController;
      expect(planner.guidanceRequestCount, 1);
      expect((await repository.load()).signals, isEmpty);
    },
  );

  testWidgets('Spanish priority consent stays localized and defaults off', (
    WidgetTester tester,
  ) async {
    final AccountStorageScope scope = AccountStorageScope.authenticated(
      'spanish-context-account',
    );
    final _MemoryPrefs store = _MemoryPrefs();
    final PersonContextRepository repository = PersonContextRepository(
      store,
      scope,
    );
    final ProviderContainer container = _container(
      accountScope: scope,
      sharedPrefsStore: store,
      personContextRepository: repository,
      firstUseContextOfferSeen: false,
    );
    addTearDown(container.dispose);
    await _pumpPlanner(tester, container, locale: const Locale('es'));
    await _scrollTo(tester, find.byKey(const Key('planner-context-field')));
    await tester.enterText(
      find.byKey(const Key('planner-context-field')),
      'Preparar la prueba cerrada.',
    );
    await _requestGuidance(tester);
    await _scrollTo(tester, find.byKey(const Key('first-use-context-add')));
    await tester.tap(find.byKey(const Key('first-use-context-add')));
    await tester.pump();

    expect(find.text('¿Guardar tu prioridad actual?'), findsOneWidget);
    expect(find.textContaining('No añadas un perfil'), findsOneWidget);
    expect(
      find.textContaining('Propósito: apoyo para decisiones'),
      findsOneWidget,
    );
    expect(find.text('Guardar con consentimiento'), findsOneWidget);
    expect(find.text('Save your current priority?'), findsNothing);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('first-use-context-confirm')),
          )
          .onPressed,
      isNull,
    );
    expect((await repository.load()).signals, isEmpty);
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
    expect(find.text('ON-DEVICE PLANNER V2 · DETERMINISTIC'), findsOneWidget);
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
      expect(find.text('ON-DEVICE PLANNER V2 · DETERMINISTIC'), findsOneWidget);
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
        smartPlannerAvailabilityProvider.overrideWith((Ref ref) async => true),
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

  testWidgets('blocked account cannot dispatch a guidance request', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = _container(plannerAvailable: false);
    addTearDown(container.dispose);
    await _pumpPlanner(tester, container);

    await _scrollTo(tester, find.text('PLANNER UNAVAILABLE'));
    expect(
      find.text(
        'Smart Planner is not enabled for this account. No guidance request will be sent.',
      ),
      findsOneWidget,
    );
    expect(find.text('GET GUIDANCE'), findsNothing);

    await tester.tap(find.text('PLANNER UNAVAILABLE'));
    await tester.pump();

    final _PlannerV2TestController planner =
        container.read(smartPlannerQueryControllerProvider)
            as _PlannerV2TestController;
    expect(planner.guidanceRequestCount, 0);
  });

  testWidgets('renders the calm Planner V2 action set', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = _container();
    addTearDown(container.dispose);
    await _pumpPlanner(tester, container);
    await _requestGuidance(tester);

    await _scrollTo(tester, find.text('PLANNER V2'));
    expect(find.text('ON-DEVICE PLANNER V2 · DETERMINISTIC'), findsOneWidget);
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
    final List<_RecordedOutcome> outcomes = <_RecordedOutcome>[];
    final ProviderContainer container = _container(
      operatingReceipt: _screenOperatingReceipt(),
      outcomes: outcomes,
    );
    addTearDown(container.dispose);
    await _pumpPlanner(tester, container);
    await _requestGuidance(tester);
    await tester.pump();

    expect(
      outcomes.map((_RecordedOutcome outcome) => outcome.kind),
      <DecisionOutcomeKind>[DecisionOutcomeKind.shown],
    );

    await _scrollTo(tester, find.text('Make smaller'));
    await tester.tap(find.text('Make smaller'));
    await tester.pump();
    expect(outcomes.last.kind, DecisionOutcomeKind.deferred);

    await _scrollTo(tester, find.text('Different approach'));
    await tester.tap(find.text('Different approach'));
    await tester.pump();
    expect(outcomes.last.kind, DecisionOutcomeKind.rejected);
    expect(outcomes.last.optionChosen, PlannerOptionKind.minimum.name);

    await _scrollTo(tester, find.text('Use this plan'));
    await tester.tap(find.text('Use this plan'));
    await tester.pump();

    expect(outcomes.last.kind, DecisionOutcomeKind.accepted);
    expect(
      outcomes.where(
        (_RecordedOutcome outcome) => outcome.kind == DecisionOutcomeKind.shown,
      ),
      hasLength(1),
    );
    expect(container.read(creatorDraftPreviewProvider), isNotNull);
    expect(container.read(appFlowProvider), AppView.creator);
  });

  testWidgets(
    'behavior-relevant Person Context change clears a displayed plan before use',
    (WidgetTester tester) async {
      final ProviderContainer container = _container();
      addTearDown(container.dispose);
      await _pumpPlanner(tester, container);
      await _requestGuidance(tester);

      expect(find.text('Use this plan'), findsOneWidget);
      expect(container.read(creatorDraftPreviewProvider), isNull);

      container
          .read(_plannerContextRevisionTestProvider.notifier)
          .setRevision('revision-b');
      await tester.pump();

      expect(find.text('Use this plan'), findsNothing);
      expect(
        find.text(
          'Your Person Context changed, so the previous guidance was cleared. Tap GET GUIDANCE to review a current plan.',
        ),
        findsOneWidget,
      );
      expect(container.read(creatorDraftPreviewProvider), isNull);
    },
  );

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

  testWidgets('Spanish durable-memory disclosure remains fully localized', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = _container();
    addTearDown(container.dispose);
    await _pumpPlanner(tester, container, locale: const Locale('es'));
    await _requestGuidance(tester);

    final Finder remember = find.byKey(
      const Key('planner-remember-preference'),
    );
    await _scrollTo(tester, remember);
    await tester.tap(remember);
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.text('¿Recordar una preferencia del Planificador Inteligente?'),
      findsOneWidget,
    );
    expect(find.textContaining('Vista previa del recibo'), findsOneWidget);
    expect(find.textContaining('Límite de recuperación'), findsOneWidget);
    expect(find.text('Usar solo esta vez'), findsOneWidget);
    expect(find.text('Remember a Smart Planner preference?'), findsNothing);
  });

  testWidgets(
    'optional explanation quotes before send and cancel executes zero',
    (WidgetTester tester) async {
      final _FakePlannerExplanationPort explanation =
          _FakePlannerExplanationPort();
      final ProviderContainer container = _container(
        explanationPort: explanation,
      );
      addTearDown(container.dispose);
      await _pumpPlanner(tester, container);
      await _requestGuidance(tester);

      final Finder request = find.byKey(
        const Key('planner-explanation-request'),
      );
      await _scrollTo(tester, request);
      await tester.tap(request);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(explanation.quoteCalls, 1);
      expect(explanation.executeCalls, 0);
      expect(find.text('Provider: Anthropic'), findsOneWidget);
      expect(find.text('Expected cost: 2 AI credits'), findsOneWidget);
      expect(find.text('• visible deterministic plan clauses'), findsOneWidget);
      expect(find.text('• visible evidence summaries'), findsOneWidget);

      await tester.tap(find.byKey(const Key('planner-explanation-cancel')));
      await tester.pump(const Duration(milliseconds: 300));

      expect(explanation.executeCalls, 0);
      expect(find.byKey(const Key('planner-explanation-result')), findsNothing);
      expect(find.text('Balanced release block'), findsOneWidget);
      expect(find.byKey(const Key('planner-use-this-plan')), findsOneWidget);
    },
  );

  testWidgets(
    'confirmed explanation is read-only and keeps deterministic plan',
    (WidgetTester tester) async {
      final _FakePlannerExplanationPort explanation =
          _FakePlannerExplanationPort();
      final ProviderContainer container = _container(
        explanationPort: explanation,
      );
      addTearDown(container.dispose);
      await _pumpPlanner(tester, container);
      await _requestGuidance(tester);

      final Finder request = find.byKey(
        const Key('planner-explanation-request'),
      );
      await _scrollTo(tester, request);
      await tester.tap(request);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const Key('planner-explanation-confirm')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(explanation.quoteCalls, 1);
      expect(explanation.executeCalls, 1);
      expect(
        find.text('This wording explains the visible recommendation.'),
        findsOneWidget,
      );
      expect(find.text('Balanced release block'), findsOneWidget);
      expect(find.byKey(const Key('planner-use-this-plan')), findsOneWidget);
    },
  );

  testWidgets('failed execution retries the same quoted request once', (
    WidgetTester tester,
  ) async {
    final _FakePlannerExplanationPort explanation = _FakePlannerExplanationPort(
      failFirstExecution: true,
    );
    final ProviderContainer container = _container(
      explanationPort: explanation,
    );
    addTearDown(container.dispose);
    await _pumpPlanner(tester, container);
    await _requestGuidance(tester);

    final Finder request = find.byKey(const Key('planner-explanation-request'));
    await _scrollTo(tester, request);
    await tester.tap(request);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const Key('planner-explanation-confirm')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(explanation.quoteCalls, 1);
    expect(explanation.executeCalls, 1);
    expect(find.byKey(const Key('planner-explanation-error')), findsOneWidget);

    await _scrollTo(tester, request);
    await tester.tap(request);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(explanation.quoteCalls, 1);
    expect(explanation.executeCalls, 2);
    expect(explanation.requestIds, <String>{'planner-request-test'});
    expect(find.byKey(const Key('planner-explanation-result')), findsOneWidget);
  });
}

ProviderContainer _container({
  VoiceService? voiceService,
  OperatingDecisionReceipt? operatingReceipt,
  List<_RecordedOutcome>? outcomes,
  AccountStorageScope? accountScope,
  SmartPlannerQueryController Function(Ref)? plannerBuilder,
  PlannerExplanationPort? explanationPort,
  bool plannerAvailable = true,
  bool firstUseContextOfferSeen = true,
  SharedPrefsStore? sharedPrefsStore,
  PersonContextRepository? personContextRepository,
}) {
  final SharedPrefsStore resolvedStore = sharedPrefsStore ?? _MemoryPrefs();
  final AccountStorageScope resolvedScope =
      accountScope ?? AccountStorageScope.authenticated('planner-test-account');
  if (firstUseContextOfferSeen && resolvedStore is _MemoryPrefs) {
    resolvedStore
            .values['chronospark.first_use_context_offer.v1.${resolvedScope.v2Namespace}'] =
        'true';
  }
  return ProviderContainer(
    overrides: [
      accountStorageScopeProvider.overrideWithValue(resolvedScope),
      accountLegacyOwnershipProvider.overrideWithValue(
        LegacyScopeOwnership.provenNotOwned,
      ),
      sharedPrefsStoreProvider.overrideWithValue(resolvedStore),
      if (personContextRepository != null)
        personContextRepositoryProvider.overrideWithValue(
          personContextRepository,
        ),
      smartPlannerQueryControllerProvider.overrideWith(
        plannerBuilder ?? _PlannerV2TestController.new,
      ),
      smartPlannerPersonContextBehaviorRevisionProvider.overrideWith(
        (Ref ref) => ref.watch(_plannerContextRevisionTestProvider),
      ),
      smartPlannerPersonContextBehaviorRevisionForDecisionProvider.overrideWith(
        (Ref ref, String decisionText) =>
            ref.watch(_plannerContextRevisionTestProvider),
      ),
      smartPlannerAvailabilityProvider.overrideWith(
        (Ref ref) async => plannerAvailable,
      ),
      voiceServiceProvider.overrideWithValue(
        voiceService ?? _NoopVoiceService(),
      ),
      smartPlannerOperatingReceiptProvider.overrideWithValue(operatingReceipt),
      decisionOutcomeActionsProvider.overrideWith(
        (Ref ref) => _RecordingDecisionOutcomeActions(
          ref,
          outcomes ?? <_RecordedOutcome>[],
        ),
      ),
      if (explanationPort != null)
        plannerExplanationAvailabilityProvider.overrideWith(
          (Ref ref) async => PlannerExplanationAvailability.available,
        ),
      if (explanationPort != null)
        plannerExplanationPortProvider.overrideWith(
          (Ref ref) async => explanationPort,
        ),
    ],
  );
}

class _MemoryPrefs implements SharedPrefsStore {
  final Map<String, String> values = <String, String>{};

  @override
  Future<void> init() async {}

  @override
  String? load(String key) => values[key];

  @override
  Future<void> save(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<void> clear() async => values.clear();
}

final _plannerContextRevisionTestProvider =
    NotifierProvider<_PlannerContextRevisionTestNotifier, String>(
      _PlannerContextRevisionTestNotifier.new,
    );

class _PlannerContextRevisionTestNotifier extends Notifier<String> {
  @override
  String build() => 'revision-a';

  void setRevision(String revision) => state = revision;
}

Future<void> _pumpPlanner(
  WidgetTester tester,
  ProviderContainer container, {
  double textScale = 1,
  Locale locale = const Locale('en'),
}) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: locale,
        supportedLocales: ChronoSparkLocalizations.supportedLocales,
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          ChronoSparkLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
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
  final Finder guidanceButton = find.byKey(
    const Key('planner-guidance-button'),
  );
  await _scrollTo(tester, guidanceButton);
  await tester.tap(guidanceButton);
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
  Future<SmartPlannerResult> requestPlanningGuidance({
    required double? energy,
    required EmotionalState? emotion,
    required String notes,
    required List<Map<String, String>> history,
    required String? previousSavedNotes,
    String? supportivePauseReason,
    String? supportiveQuestion,
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
    String? supportivePauseReason,
    String? supportiveQuestion,
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
    String? supportivePauseReason,
    String? supportiveQuestion,
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
    String? supportivePauseReason,
    String? supportiveQuestion,
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
    String? supportivePauseReason,
    String? supportiveQuestion,
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

OperatingDecisionReceipt _screenOperatingReceipt() {
  final DateTime now = DateTime.now().toUtc();
  final DateTime generatedAt = now.subtract(const Duration(hours: 1));
  return OperatingDecisionReceipt(
    decisionId: 'screen-receipt',
    subjectId: null,
    recommendedAction: 'Prepare release evidence',
    rationale: 'The release evidence matches the current Planner request.',
    whyItMatters: 'The release gate needs one verified decision.',
    consequenceOfDelay: 'The release gate remains unresolved.',
    generatedAt: generatedAt,
    expiresAt: now.add(const Duration(hours: 1)),
    confidence: OperatingConfidence.moderate,
    evidence: <OperatingEvidence>[
      OperatingEvidence(
        code: 'release-evidence',
        description: 'Release evidence is incomplete.',
        kind: OperatingEvidenceKind.observed,
        recordedAt: generatedAt,
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
}

class _RecordingDecisionOutcomeActions extends DecisionOutcomeActions {
  _RecordingDecisionOutcomeActions(super.ref, this.outcomes);

  final List<_RecordedOutcome> outcomes;

  @override
  Future<void> record({
    required OperatingDecisionReceipt receipt,
    required DecisionOutcomeKind kind,
    required String surface,
    String? detail,
    String? situation,
    String? optionChosen,
    int? optionSizeMinutes,
    String? deferralReason,
    String? completionResult,
    bool? recommendationHelped,
  }) async {
    expect(receipt.decisionId, 'screen-receipt');
    expect(surface, 'smart_planner');
    outcomes.add(_RecordedOutcome(kind: kind, optionChosen: optionChosen));
  }
}

class _RecordedOutcome {
  const _RecordedOutcome({required this.kind, this.optionChosen});

  final DecisionOutcomeKind kind;
  final String? optionChosen;
}

class _FakePlannerExplanationPort implements PlannerExplanationPort {
  _FakePlannerExplanationPort({this.failFirstExecution = false});

  final bool failFirstExecution;
  int quoteCalls = 0;
  int executeCalls = 0;
  final Set<String> requestIds = <String>{};

  @override
  Future<PlannerExplanationQuote> quote(PlannerExplanationPacket packet) async {
    quoteCalls += 1;
    return PlannerExplanationQuote.fromJson(<String, Object?>{
      'schemaVersion': plannerExplanationSchemaVersion,
      'operation': 'quote',
      'surface': plannerExplanationSurface,
      'requestId': 'planner-request-test',
      'quoteId': 'planner-quote-test',
      'expectedCredits': 2,
      'provider': 'Anthropic',
      'modelLabel': 'server-selected-model',
      'promptVersion': 'planner-explanation-v1',
      'responseSchemaVersion': plannerExplanationSchemaVersion,
      'disclosureVersion': plannerExplanationDisclosureVersion,
      'transmittedDataCategories': <String>[
        'visible deterministic plan clauses',
        'visible evidence summaries',
      ],
      'replayWindowSeconds': 240,
      'providerRetentionStatus': 'verified_external_gate',
      'expiresAt': DateTime.now()
          .toUtc()
          .add(const Duration(minutes: 4))
          .toIso8601String(),
    });
  }

  @override
  Future<PlannerExplanationResult> execute({
    required PlannerExplanationPacket packet,
    required PlannerExplanationQuote quote,
  }) async {
    executeCalls += 1;
    requestIds.add(quote.requestId);
    if (failFirstExecution && executeCalls == 1) {
      throw const PlannerExplanationServiceException(
        'simulated_timeout',
        'simulated timeout',
      );
    }
    return PlannerExplanationResult.fromJson(<String, Object?>{
      'schemaVersion': plannerExplanationSchemaVersion,
      'operation': 'execute',
      'surface': plannerExplanationSurface,
      'requestId': quote.requestId,
      'status': 'completed',
      'responseDigest': packet.responseDigest,
      'explanation': 'This wording explains the visible recommendation.',
      'sourceClauseIds': <String>['recommended_title', 'recommendation_reason'],
      'provider': quote.provider,
      'modelLabel': quote.modelLabel,
      'promptVersion': quote.promptVersion,
      'responseSchemaVersion': plannerExplanationSchemaVersion,
      'expectedCredits': quote.expectedCredits,
      'creditsCharged': quote.expectedCredits,
      'remainingCredits': 8,
      'contentExpiresAt': DateTime.now()
          .toUtc()
          .add(const Duration(minutes: 5))
          .toIso8601String(),
      'replayState': executeCalls == 1 ? 'fresh' : 'replayed',
    });
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
