import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/domain/entities/plan_entity.dart';
import 'package:fantastic_guacamole/domain/entities/plan_proposal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_plan_repository.dart';
import 'package:fantastic_guacamole/features/home/ui/smart_planner_screen.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/state/models/ai_recommendation.dart';
import 'package:fantastic_guacamole/state/state/emotional_state.dart';
import 'package:fantastic_guacamole/system/voice/voice_service.dart';
import 'package:fantastic_guacamole/ui/widgets/error_boundary_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'starts without fallback guidance, follow-up box, or cheat sheet',
    (WidgetTester tester) async {
      final ProviderContainer container = ProviderContainer(
        overrides: [
          smartPlannerQueryControllerProvider.overrideWith(
            _ConversationalSmartPlannerQueryController.new,
          ),
          voiceServiceProvider.overrideWithValue(_NoopVoiceService()),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: ErrorBoundary(child: SmartPlannerScreen()),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await _scrollToText(tester, 'Preview Plan');

      expect(
        find.text('Stabilize scope and execute one specific action now.'),
        findsNothing,
      );
      expect(find.text('Send a follow-up question...'), findsNothing);
      expect(find.textContaining('Get Guidance cheat sheet'), findsNothing);
      expect(find.text('Preview Plan'), findsOneWidget);
    },
  );

  testWidgets('previews and applies a plan proposal from saved tasks', (
    WidgetTester tester,
  ) async {
    final _PlanRepository planRepository = _PlanRepository();
    final ProviderContainer container = ProviderContainer(
      overrides: [
        domainPlanRepositoryProvider.overrideWithValue(planRepository),
        tasksProvider.overrideWith((ref) async {
          return <Task>[
            Task(
              id: 'task-1',
              title: 'Write launch checklist',
              priority: 4,
              difficulty: 2,
              energyRequired: 2,
              scheduledFor: DateTime(2026, 8, 19, 9),
            ),
          ];
        }),
        smartPlannerQueryControllerProvider.overrideWith(
          _ConversationalSmartPlannerQueryController.new,
        ),
        voiceServiceProvider.overrideWithValue(_NoopVoiceService()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: ErrorBoundary(child: SmartPlannerScreen()),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await _scrollToText(tester, 'Preview Plan');

    final Finder previewButton = find.widgetWithText(
      ElevatedButton,
      'Preview Plan',
    );
    await tester.ensureVisible(previewButton);
    await tester.pump();
    final ElevatedButton preview = tester.widget<ElevatedButton>(previewButton);
    expect(preview.onPressed, isNotNull);
    await tester.runAsync(() async {
      preview.onPressed!();
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    final AsyncValue<PlanProposalEntity?> proposalState = container.read(
      planProposalProvider,
    );
    expect(proposalState.hasError, isFalse);
    expect(proposalState.asData?.value, isNotNull);

    expect(find.textContaining('Preview plan:'), findsOneWidget);
    expect(find.text('Write launch checklist'), findsOneWidget);

    final Finder applyButton = find.widgetWithText(
      OutlinedButton,
      'Apply to Timeline',
    );
    await tester.ensureVisible(applyButton);
    await tester.pump();
    final OutlinedButton apply = tester.widget<OutlinedButton>(applyButton);
    expect(apply.onPressed, isNotNull);
    await tester.runAsync(() async {
      apply.onPressed!();
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(container.read(appFlowProvider), AppView.timeline);
  });

  testWidgets('shows guidance provenance, evidence, and freshness', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = ProviderContainer(
      overrides: [
        smartPlannerQueryControllerProvider.overrideWith(
          _EvidenceSmartPlannerQueryController.new,
        ),
        voiceServiceProvider.overrideWithValue(_NoopVoiceService()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: ErrorBoundary(child: SmartPlannerScreen()),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await _tapPrimaryPlannerButton(tester);
    await tester.pump(const Duration(milliseconds: 300));
    final Finder evidenceBlock = find.textContaining('EXTERNAL ASSISTANT');
    await tester.scrollUntilVisible(
      evidenceBlock,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();

    expect(evidenceBlock, findsOneWidget);
    expect(find.textContaining('Evidence: Active tasks: 3'), findsOneWidget);
    expect(
      find.textContaining('you choose whether to apply it'),
      findsOneWidget,
    );
  });

  testWidgets(
    'renders ErrorBoundary and recovers on retry after planner request failure',
    (WidgetTester tester) async {
      final ProviderContainer container = ProviderContainer(
        overrides: [
          smartPlannerQueryControllerProvider.overrideWith(
            _FlakySmartPlannerQueryController.new,
          ),
          voiceServiceProvider.overrideWithValue(_NoopVoiceService()),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: ErrorBoundary(child: SmartPlannerScreen()),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      await Logger.withMutedErrors(() async {
        await _tapPrimaryPlannerButton(tester);
        await tester.pump(const Duration(milliseconds: 500));
      });

      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await _tapPrimaryPlannerButton(tester);
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Something went wrong'), findsNothing);

      final Finder recoveredMessage = find.text('Recovered planning response.');
      await tester.scrollUntilVisible(
        recoveredMessage,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(recoveredMessage, findsOneWidget);
    },
  );

  testWidgets(
    'sends follow-up and renders exchange after initial planning response',
    (WidgetTester tester) async {
      final ProviderContainer container = ProviderContainer(
        overrides: [
          smartPlannerQueryControllerProvider.overrideWith(
            _ConversationalSmartPlannerQueryController.new,
          ),
          voiceServiceProvider.overrideWithValue(_NoopVoiceService()),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: ErrorBoundary(child: SmartPlannerScreen()),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      await _tapPrimaryPlannerButton(tester);
      await tester.pump(const Duration(milliseconds: 500));

      final Finder initialMessage = find.text('Initial planning response.');
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
          smartPlannerQueryControllerProvider.overrideWith(
            _CrisisFollowUpSmartPlannerQueryController.new,
          ),
          voiceServiceProvider.overrideWithValue(_NoopVoiceService()),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: ErrorBoundary(child: SmartPlannerScreen()),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      await _tapPrimaryPlannerButton(tester);
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
        smartPlannerQueryControllerProvider.overrideWith(
          _ConversationalSmartPlannerQueryController.new,
        ),
        voiceServiceProvider.overrideWithValue(_NoopVoiceService()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: ErrorBoundary(child: SmartPlannerScreen()),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    final Finder creatorEntry = find.text('OPEN CREATOR');
    expect(creatorEntry, findsOneWidget);

    await tester.tap(creatorEntry);
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull);
  });
}

class _FlakySmartPlannerQueryController extends SmartPlannerQueryController {
  _FlakySmartPlannerQueryController(super.ref);

  int _attempts = 0;

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
    _attempts += 1;
    if (_attempts == 1) {
      throw StateError('simulated planner failure');
    }

    return SmartPlannerResult(
      prompt: 'practical planning guidance check-in',
      message: 'Recovered planning response.',
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

class _PlanRepository implements IPlanRepository {
  PlanEntity? plan;
  PlanProposalEntity? proposal;

  @override
  Future<void> applyProposal({
    required PlanProposalEntity proposal,
    required PlanEntity plan,
  }) async {
    this.proposal = proposal;
    this.plan = plan;
  }

  @override
  Future<PlanEntity?> getPlan(DateTime date) async => plan;

  @override
  Future<PlanProposalEntity?> getProposal(String id) async => proposal;

  @override
  Future<void> savePlan(PlanEntity value) async => plan = value;

  @override
  Future<void> saveProposal(PlanProposalEntity value) async => proposal = value;
}

class _ConversationalSmartPlannerQueryController
    extends SmartPlannerQueryController {
  _ConversationalSmartPlannerQueryController(super.ref);

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
    return SmartPlannerResult(
      prompt: 'practical planning guidance check-in',
      message: 'Initial planning response.',
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

class _EvidenceSmartPlannerQueryController extends SmartPlannerQueryController {
  _EvidenceSmartPlannerQueryController(super.ref);

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
    return SmartPlannerResult(
      prompt: 'Plan today',
      message: 'Use one grounded action.',
      savedNotes: null,
      processingMode: AIProcessingMode.external,
      evidence: const <String>['Active tasks: 3'],
      generatedAt: DateTime.now(),
    );
  }
}

class _CrisisFollowUpSmartPlannerQueryController
    extends SmartPlannerQueryController {
  _CrisisFollowUpSmartPlannerQueryController(super.ref);

  @override
  bool detectsCrisis(String text) => text.toLowerCase().contains('kill myself');

  @override
  Future<SmartPlannerResult> requestPlanningGuidance({
    required double energy,
    required EmotionalState emotion,
    required String notes,
    required List<Map<String, String>> history,
    required String? previousSavedNotes,
  }) async {
    return SmartPlannerResult(
      prompt: 'practical planning guidance check-in',
      message: 'Initial planning response.',
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

Future<void> _tapPrimaryPlannerButton(WidgetTester tester) async {
  final Finder cta = find.text('GET GUIDANCE');
  await tester.scrollUntilVisible(
    cta,
    250,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(cta.first, warnIfMissed: false);
  await tester.pump();
}

Future<void> _scrollToText(WidgetTester tester, String text) async {
  await tester.scrollUntilVisible(
    find.text(text),
    250,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(find.text(text));
  await tester.pump();
  await tester.drag(find.byType(Scrollable).first, const Offset(0, -120));
  await tester.pump();
}
