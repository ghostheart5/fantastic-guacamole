import 'dart:io';

import 'package:fantastic_guacamole/domain/entities/assistant_contracts.dart';
import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/planner_v2_response.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_goal_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
import 'package:fantastic_guacamole/domain/policies/assistant_safety_policy.dart';
import 'package:fantastic_guacamole/domain/release/assistant_release_control.dart';
import 'package:fantastic_guacamole/state/controllers/smart_planner_query_controller.dart';
import 'package:fantastic_guacamole/state/models/ai_recommendation.dart';
import 'package:fantastic_guacamole/state/models/personalization_models.dart';
import 'package:fantastic_guacamole/state/providers/assistant_release_provider.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/personalization_provider.dart';
import 'package:fantastic_guacamole/state/state/emotional_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ProviderContainer plannerContainer({
    _MemoryTaskRepository? tasks,
    _MemoryGoalRepository? goals,
    bool emotionConsent = true,
  }) => ProviderContainer(
    overrides: [
      assistantReleaseConfigProvider.overrideWith(
        (Ref ref) async => AssistantReleaseConfig(
          stage: AssistantReleaseStage.general,
          canaryBasisPoints: 0,
          shadowEvaluationEnabled: false,
          internalAccountDigests: const <String>{},
          rollbackCapabilities: const <AssistantReleaseCapability>{},
        ),
      ),
      domainTaskRepositoryProvider.overrideWithValue(
        tasks ?? _MemoryTaskRepository(),
      ),
      domainGoalRepositoryProvider.overrideWithValue(
        goals ?? _MemoryGoalRepository(),
      ),
      smartPlannerClockProvider.overrideWithValue(
        () => DateTime.utc(2026, 8, 29, 18),
      ),
      personalizationProfileProvider.overrideWith(
        emotionConsent
            ? _ConsentedPersonalizationController.new
            : _RevokedPersonalizationController.new,
      ),
    ],
  );

  test('Planner V2 returns the complete typed response contract', () async {
    final ProviderContainer container = plannerContainer();
    addTearDown(container.dispose);
    final SmartPlannerQueryController controller = container.read(
      smartPlannerQueryControllerProvider,
    );

    final SmartPlannerResult result = await controller.requestPlanningGuidance(
      energy: 0.61,
      emotion: EmotionalState.calm,
      notes: 'I need to focus on the launch checklist',
      history: const <Map<String, String>>[],
      previousSavedNotes: 'must not be reused or changed',
    );

    final PlannerV2Response response = result.plannerResponse;
    expect(response.whatIHeard, contains('launch checklist'));
    expect(response.mattersMost, isNotEmpty);
    expect(
      response.verifiedEvidence,
      contains(
        'Saved planning evidence checked: no active tasks or goals were found for this account.',
      ),
    );
    expect(
      response.options.map((PlannerOption option) => option.kind),
      containsAllInOrder(PlannerOptionKind.values),
    );
    expect(response.recommendedOption.kind, PlannerOptionKind.bestFit);
    expect(response.recommendationReason, isNotEmpty);
    expect(response.nextStep, isNotEmpty);
    expect(response.usefulQuestion, isNotEmpty);
    expect(response.adaptationReceipt.energyPercent, 61);
    expect(response.adaptationReceipt.userSelectedEmotion, EmotionalState.calm);
    expect(response.controls, containsAll(PlannerActionControl.values));
    expect(response.origin, PlannerResponseOrigin.deterministic);
    expect(result.savedNotes, isNull);
    expect(result.processingMode, AIProcessingMode.onDevice);
    expect(result.evidence, contains(contains('not AI-generated')));
    result.request.validate();
    result.response.validateAgainst(result.request);
    result.evidenceManifest.validateAgainstResponse(result.response);
    expect(
      result.safetyReceipt.disposition,
      AssistantSafetyDisposition.approved,
    );
  });

  test(
    'revoked emotion consent removes emotion from Planner context',
    () async {
      final ProviderContainer container = plannerContainer(
        emotionConsent: false,
      );
      addTearDown(container.dispose);

      final SmartPlannerResult result = await container
          .read(smartPlannerQueryControllerProvider)
          .requestPlanningGuidance(
            energy: 0.9,
            emotion: EmotionalState.engaged,
            notes: 'Choose a practical next step.',
            history: const <Map<String, String>>[],
            previousSavedNotes: null,
          );

      expect(result.request.context, isNot(contains('emotion')));
      expect(result.request.context['emotionEvidence'], 'unavailable');
      expect(
        result.plannerResponse.adaptationReceipt.userSelectedEmotion,
        isNull,
      );
      expect(result.plannerResponse.recommendedKind, PlannerOptionKind.bestFit);
      expect(
        result.plannerResponse.verifiedEvidence,
        contains('Current emotional state was not used.'),
      );
    },
  );

  test(
    'low energy and anxious self-report recommend Minimum without inference',
    () async {
      final ProviderContainer container = plannerContainer();
      addTearDown(container.dispose);
      final SmartPlannerQueryController controller = container.read(
        smartPlannerQueryControllerProvider,
      );

      final SmartPlannerResult result = await controller
          .requestPlanningGuidance(
            energy: 0.31,
            emotion: EmotionalState.anxious,
            notes: 'My work deadline feels overloaded',
            history: const <Map<String, String>>[],
            previousSavedNotes: null,
          );

      expect(result.plannerResponse.recommendedKind, PlannerOptionKind.minimum);
      expect(
        result.plannerResponse.adaptationReceipt.adjustments,
        contains(
          'Used only your selected emotion; no emotion was inferred from your text.',
        ),
      );
      expect(result.message, contains('Minimum:'));
      expect(result.message, contains('Best-fit:'));
      expect(result.message, contains('Stretch:'));
    },
  );

  test('fatigued recovery guidance uses clear actionable language', () {
    final ProviderContainer container = plannerContainer();
    addTearDown(container.dispose);
    final SmartPlannerQueryController controller = container.read(
      smartPlannerQueryControllerProvider,
    );

    final PlannerV2Response response = controller.buildPlannerResponse(
      input: 'im tired',
      energy: 0.3,
      emotion: EmotionalState.fatigued,
      contextWasProvided: true,
    );

    expect(response.recommendedKind, PlannerOptionKind.minimum);
    expect(response.recommendedOption.title, 'Protect your energy');
    expect(
      response.recommendedOption.tradeoff,
      'This may delay one low-priority task, but it protects your energy right now.',
    );
    expect(
      response.nextStep,
      'Choose one nonessential task to postpone. Then take a five-minute quiet break.',
    );
    expect(response.nextStep, isNot(contains('im tired')));
  });

  test('high energy and engaged self-report can recommend Stretch', () async {
    final ProviderContainer container = plannerContainer();
    addTearDown(container.dispose);
    final SmartPlannerQueryController controller = container.read(
      smartPlannerQueryControllerProvider,
    );

    final PlannerV2Response response =
        (await controller.requestPlanningGuidance(
          energy: 0.9,
          emotion: EmotionalState.engaged,
          notes: 'Advance the next goal milestone',
          history: const <Map<String, String>>[],
          previousSavedNotes: null,
        )).plannerResponse;

    expect(response.recommendedKind, PlannerOptionKind.stretch);
    expect(response.recommendedOption.estimatedMinutes, 60);
  });

  test(
    'saved tasks and goals ground every option without any repository write',
    () async {
      final _MemoryTaskRepository tasks = _MemoryTaskRepository(<TaskEntity>[
        TaskEntity(
          id: 'task-release',
          title: 'Finish Play release checklist',
          description: 'Verify the final launch evidence.',
          createdAt: DateTime.utc(2026, 8, 20),
          priority: 5,
          energyRequired: 3,
          estimatedDuration: const Duration(minutes: 45),
          scheduledFor: DateTime.utc(2026, 8, 29, 20),
          goalId: 'goal-launch',
        ),
        TaskEntity(
          id: 'task-done',
          title: 'Already completed setup',
          createdAt: DateTime.utc(2026, 8, 18),
          isCompleted: true,
          completedAt: DateTime.utc(2026, 8, 19),
        ),
      ]);
      final _MemoryGoalRepository goals = _MemoryGoalRepository(<GoalEntity>[
        GoalEntity(
          id: 'goal-launch',
          title: 'Launch ChronoSpark',
          createdAt: DateTime.utc(2026, 8, 1),
          targetDate: DateTime.utc(2026, 9, 1),
        ),
      ]);
      final ProviderContainer container = plannerContainer(
        tasks: tasks,
        goals: goals,
      );
      addTearDown(container.dispose);

      final SmartPlannerResult result = await container
          .read(smartPlannerQueryControllerProvider)
          .requestPlanningGuidance(
            energy: 0.61,
            emotion: EmotionalState.calm,
            notes: 'What should I focus on for the Play release checklist?',
            history: const <Map<String, String>>[],
            previousSavedNotes: null,
          );

      expect(
        result.plannerResponse.options.every(
          (PlannerOption option) =>
              option.description.contains('Finish Play release checklist'),
        ),
        isTrue,
      );
      expect(
        result.plannerResponse.verifiedEvidence,
        contains(
          contains('Focused saved task: "Finish Play release checklist"'),
        ),
      );
      expect(
        result.plannerResponse.verifiedEvidence,
        contains(contains('Focused saved goal: "Launch ChronoSpark"')),
      );
      expect(result.request.context['storedEvidenceUsed'], isTrue);
      expect(result.request.context['activeTaskCount'], 1);
      expect(result.request.context['activeGoalCount'], 1);
      expect(tasks.readCalls, 1);
      expect(goals.readCalls, 1);
      expect(tasks.writeCalls, 0);
      expect(goals.writeCalls, 0);
    },
  );

  test('a matching saved goal grounds guidance when no task exists', () async {
    final _MemoryGoalRepository goals = _MemoryGoalRepository(<GoalEntity>[
      GoalEntity(
        id: 'goal-album',
        title: 'Finish the GhostHeart album',
        createdAt: DateTime.utc(2026, 8, 1),
        targetDate: DateTime.utc(2026, 10, 1),
      ),
    ]);
    final ProviderContainer container = plannerContainer(goals: goals);
    addTearDown(container.dispose);

    final SmartPlannerResult result = await container
        .read(smartPlannerQueryControllerProvider)
        .requestPlanningGuidance(
          energy: 0.7,
          emotion: EmotionalState.engaged,
          notes: 'How do I move the GhostHeart album goal forward?',
          history: const <Map<String, String>>[],
          previousSavedNotes: null,
        );

    expect(
      result.plannerResponse.options.every(
        (PlannerOption option) =>
            option.description.contains('Finish the GhostHeart album'),
      ),
      isTrue,
    );
    expect(result.request.context['focusedEvidenceKind'], 'goal');
    expect(
      result.plannerResponse.verifiedEvidence,
      contains(contains('Focused saved goal: "Finish the GhostHeart album"')),
    );
    expect(goals.writeCalls, 0);
  });

  test('follow-up uses saved evidence and prior user conversation', () async {
    final _MemoryTaskRepository tasks = _MemoryTaskRepository(<TaskEntity>[
      TaskEntity(
        id: 'task-release',
        title: 'Finish Play release checklist',
        createdAt: DateTime.utc(2026, 8, 20),
        priority: 4,
        estimatedDuration: const Duration(minutes: 40),
      ),
    ]);
    final ProviderContainer container = plannerContainer(tasks: tasks);
    addTearDown(container.dispose);
    final SmartPlannerQueryController controller = container.read(
      smartPlannerQueryControllerProvider,
    );

    final SmartPlannerResult result = await controller.requestFollowUpResult(
      input: 'Can you make the habit easier to repeat?',
      energy: 0.45,
      emotion: EmotionalState.neutral,
      reflection: 'I need to finish the Play release checklist.',
      history: const <Map<String, String>>[
        <String, String>{
          'role': 'user',
          'content': 'Help me finish the Play release checklist.',
        },
        <String, String>{
          'role': 'assistant',
          'content': 'Earlier deterministic plan.',
        },
      ],
    );

    expect(result.request.kind, AssistantRequestKind.followUp);
    expect(result.savedNotes, isNull);
    expect(result.plannerResponse.options, hasLength(3));
    expect(result.plannerResponse.origin, PlannerResponseOrigin.deterministic);
    expect(
      result.plannerResponse.whatIHeard,
      contains('Finish Play release checklist'),
    );
    expect(
      result.plannerResponse.options.every(
        (PlannerOption option) =>
            option.description.contains('Finish Play release checklist'),
      ),
      isTrue,
    );
    expect(
      result.plannerResponse.verifiedEvidence,
      contains(contains('prior user conversation turn')),
    );
    expect(result.request.context['conversationTurnsUsed'], 2);
    expect(tasks.writeCalls, 0);
  });

  test('follow-up anchors to the most recent prior user turn', () async {
    final ProviderContainer container = plannerContainer();
    addTearDown(container.dispose);

    final SmartPlannerResult result = await container
        .read(smartPlannerQueryControllerProvider)
        .requestFollowUpResult(
          input: 'Make that more specific.',
          energy: 0.55,
          emotion: EmotionalState.neutral,
          reflection: '',
          history: const <Map<String, String>>[
            <String, String>{
              'role': 'user',
              'content': 'Help me organize this week.',
            },
            <String, String>{
              'role': 'assistant',
              'content': 'Earlier deterministic plan.',
            },
            <String, String>{
              'role': 'user',
              'content': 'Focus on preparing the release notes.',
            },
          ],
        );

    expect(
      result.plannerResponse.whatIHeard,
      contains('Focus on preparing the release notes.'),
    );
  });

  test(
    'follow-up cannot bypass a crisis route in prior user context',
    () async {
      final ProviderContainer container = plannerContainer();
      addTearDown(container.dispose);

      await expectLater(
        () => container
            .read(smartPlannerQueryControllerProvider)
            .requestFollowUpResult(
              input: 'What should I do next?',
              energy: 0.2,
              emotion: EmotionalState.negative,
              reflection: '',
              history: const <Map<String, String>>[
                <String, String>{
                  'role': 'user',
                  'content': 'I want to kill myself.',
                },
              ],
            ),
        throwsA(
          isA<AssistantSafetyRouteException>().having(
            (AssistantSafetyRouteException error) => error.code,
            'code',
            'crisis_route_required',
          ),
        ),
      );
    },
  );

  test('local timeout result stays explicit and typed', () {
    final ProviderContainer container = plannerContainer();
    addTearDown(container.dispose);
    final SmartPlannerQueryController controller = container.read(
      smartPlannerQueryControllerProvider,
    );

    final SmartPlannerResult result = controller.localFallbackResult(
      input: 'Plan this task',
      message: 'The request timed out.',
      energy: 0.5,
      emotion: EmotionalState.neutral,
      history: const <Map<String, String>>[],
      reason: 'request_timeout',
    );

    expect(result.processingMode, AIProcessingMode.onDeviceFallback);
    expect(result.plannerResponse.mattersMost, 'The request timed out.');
    expect(result.evidence, contains(contains('request_timeout')));
  });

  test('Planner request path has no hidden write or stateful model hooks', () {
    final String source = File(
      'lib/state/controllers/smart_planner_query_controller.dart',
    ).readAsStringSync();
    const List<String> forbidden = <String>[
      'appendSiReflection',
      'saveMirroredMemory',
      'replaceState(',
      'emotionProvider.notifier',
      '_persistConversationTurn',
      'savePlannerMessageUseCaseProvider',
      'smartPlannerAiResponseProvider',
      'smartPlannerAiInputProvider',
      'planProposalProvider',
      'timelineActionsProvider',
      'awardXp',
      'saveTask(',
      'saveGoal(',
    ];
    for (final String token in forbidden) {
      expect(source, isNot(contains(token)), reason: 'Forbidden hook: $token');
    }
    expect(source, contains("'persistenceMode': 'ephemeral_read_only'"));
  });

  test('Planner screen has no hidden persistence, analytics, or apply hooks', () {
    final String source = File(
      'lib/features/home/ui/smart_planner_screen.dart',
    ).readAsStringSync();
    const List<String> forbidden = <String>[
      'planProposalProvider',
      'Apply to Timeline',
      'appendSiReflection',
      'adaptiveGuidanceProvider',
      'AppAnalytics.track',
      'extendedDomainBootstrapProvider',
      'memoriesActionsProvider',
      'timelineActionsProvider',
    ];
    for (final String token in forbidden) {
      expect(source, isNot(contains(token)), reason: 'Forbidden hook: $token');
    }
    expect(
      source,
      contains(
        'Used only for this check-in. Nothing is saved unless you explicitly remember a preference.',
      ),
    );
  });

  test('crisis detection remains active before planning', () {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    final SmartPlannerQueryController controller = container.read(
      smartPlannerQueryControllerProvider,
    );

    expect(controller.detectsCrisis('I want to kill myself tonight'), isTrue);
    expect(controller.detectsCrisis('I had a difficult day'), isFalse);
  });

  test('direct crisis request cannot enter ordinary planning', () async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    final SmartPlannerQueryController controller = container.read(
      smartPlannerQueryControllerProvider,
    );

    await expectLater(
      controller.requestPlanningGuidance(
        energy: 0.7,
        emotion: EmotionalState.anxious,
        notes: 'I want to kill myself tonight',
        history: const <Map<String, String>>[],
        previousSavedNotes: null,
      ),
      throwsA(
        isA<AssistantSafetyRouteException>().having(
          (AssistantSafetyRouteException error) => error.code,
          'code',
          'crisis_route_required',
        ),
      ),
    );
  });
}

class _ConsentedPersonalizationController
    extends PersonalizationProfileController {
  @override
  PersonalizationProfile build() => PersonalizationProfile(
    useEmotionSignals: true,
    emotionConsentGrantedAt: DateTime.utc(2026, 8, 29),
  );
}

class _RevokedPersonalizationController
    extends PersonalizationProfileController {
  @override
  PersonalizationProfile build() => const PersonalizationProfile();
}

class _MemoryTaskRepository implements ITaskRepository {
  _MemoryTaskRepository([List<TaskEntity> tasks = const <TaskEntity>[]])
    : _tasks = List<TaskEntity>.from(tasks);

  final List<TaskEntity> _tasks;
  int readCalls = 0;
  int writeCalls = 0;

  @override
  Future<List<TaskEntity>> getAllTasks() async {
    readCalls += 1;
    return List<TaskEntity>.from(_tasks);
  }

  @override
  Future<TaskEntity?> getTaskById(String id) async {
    readCalls += 1;
    for (final TaskEntity task in _tasks) {
      if (task.id == id) return task;
    }
    return null;
  }

  @override
  Future<void> saveTask(TaskEntity task) async {
    writeCalls += 1;
    _tasks.add(task);
  }

  @override
  Future<void> deleteTask(String id) async {
    writeCalls += 1;
    _tasks.removeWhere((TaskEntity task) => task.id == id);
  }
}

class _MemoryGoalRepository implements IGoalRepository {
  _MemoryGoalRepository([List<GoalEntity> goals = const <GoalEntity>[]])
    : _goals = List<GoalEntity>.from(goals);

  final List<GoalEntity> _goals;
  int readCalls = 0;
  int writeCalls = 0;

  @override
  List<GoalEntity> getGoals() {
    readCalls += 1;
    return List<GoalEntity>.from(_goals);
  }

  @override
  Future<void> saveGoal(GoalEntity goal) async {
    writeCalls += 1;
    _goals.add(goal);
  }

  @override
  Future<void> saveGoals(List<GoalEntity> goals) async {
    writeCalls += 1;
    _goals
      ..clear()
      ..addAll(goals);
  }

  @override
  Future<void> deleteGoal(String id) async {
    writeCalls += 1;
    _goals.removeWhere((GoalEntity goal) => goal.id == id);
  }
}
