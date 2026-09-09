import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/domain/entities/note_entity.dart';
import 'package:fantastic_guacamole/domain/entities/goal_read_health.dart';
import 'package:fantastic_guacamole/domain/planning/rhythm_planning_context.dart';
import 'package:fantastic_guacamole/state/providers/rhythm_planning_provider.dart';
import 'package:fantastic_guacamole/state/providers/planning_note_provider.dart';
import 'dart:async';
import 'dart:io';

import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/domain/entities/assistant_contracts.dart';
import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/memory_entity.dart';
import 'package:fantastic_guacamole/domain/entities/person_context.dart';
import 'package:fantastic_guacamole/domain/entities/planner_v2_response.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_goal_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
import 'package:fantastic_guacamole/domain/policies/assistant_safety_policy.dart';
import 'package:fantastic_guacamole/domain/policies/person_context_behavior_policy.dart';
import 'package:fantastic_guacamole/domain/release/assistant_release_control.dart';
import 'package:fantastic_guacamole/domain/operating_system/operating_system_contract.dart';
import 'package:fantastic_guacamole/state/controllers/smart_planner_query_controller.dart';
import 'package:fantastic_guacamole/state/models/ai_recommendation.dart';
import 'package:fantastic_guacamole/state/models/personalization_models.dart';
import 'package:fantastic_guacamole/state/providers/assistant_release_provider.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/auth_session_boundary_provider.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/memories_provider.dart';
import 'package:fantastic_guacamole/state/providers/personalization_provider.dart';
import 'package:fantastic_guacamole/state/providers/person_context_provider.dart';
import 'package:fantastic_guacamole/state/state/emotional_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final AccountStorageScope _plannerTestAccountScope =
    AccountStorageScope.authenticated('test-account');
final String _plannerTestAccountScopeId = _plannerTestAccountScope.v2Namespace!;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ProviderContainer plannerContainer({
    _MemoryTaskRepository? tasks,
    _MemoryGoalRepository? goals,
    bool emotionConsent = true,
    List<RhythmPlanningEntry> rhythms = const [],
    Future<List<RhythmPlanningEntry>>? rhythmRead,
    NoteEntity? selectedNote,
    PersonContextView? personContext,
    OperatingDecisionReceipt? operatingReceipt,
    List<MemoryEntity> plannerMemories = const <MemoryEntity>[],
  }) => ProviderContainer(
    overrides: [
      rhythmPlanningProvider.overrideWith(
        (ref) async => rhythmRead != null ? await rhythmRead : rhythms,
      ),
      selectedPlanningNoteProvider.overrideWith((ref) async => selectedNote),
      assistantReleaseConfigProvider.overrideWith(
        (Ref ref) async => AssistantReleaseConfig(
          stage: AssistantReleaseStage.general,
          canaryBasisPoints: 0,
          shadowEvaluationEnabled: false,
          internalAccountDigests: const <String>{},
          rollbackCapabilities: const <AssistantReleaseCapability>{},
        ),
      ),
      assistantBetaOptInProvider.overrideWith(_ImmediateBetaOptIn.new),
      accountStorageScopeProvider.overrideWithValue(_plannerTestAccountScope),
      domainTaskRepositoryProvider.overrideWithValue(
        tasks ?? _MemoryTaskRepository(),
      ),
      domainGoalRepositoryProvider.overrideWithValue(
        goals ?? _MemoryGoalRepository(),
      ),
      smartPlannerClockProvider.overrideWithValue(
        () => DateTime.utc(2026, 8, 29, 18),
      ),
      smartPlannerOperatingReceiptProvider.overrideWithValue(operatingReceipt),
      memoryRecallProvider(
        MemorySurface.smartPlanner,
      ).overrideWithValue(plannerMemories),
      personalizationProfileProvider.overrideWith(
        emotionConsent
            ? _ConsentedPersonalizationController.new
            : _RevokedPersonalizationController.new,
      ),
      personContextForSurfaceProvider(
        PersonContextAccessRequest(
          surface: PersonContextSurface.smartPlanner,
          purposes: operationalPersonContextPurposes,
        ),
      ).overrideWithValue(personContext),
    ],
  );

  for (final emotion in [
    EmotionalState.anxious,
    EmotionalState.fatigued,
    EmotionalState.scattered,
    EmotionalState.negative,
  ]) {
    test('urgent saved task preserves minimum for ${emotion.name}', () async {
      final tasks = _MemoryTaskRepository([
        TaskEntity(
          id: 'urgent',
          title: 'Release checklist',
          createdAt: DateTime.utc(2026, 8, 29),
          dueDate: DateTime.utc(2026, 8, 29, 20),
          energyRequired: 3,
          estimatedDuration: const Duration(minutes: 45),
        ),
      ]);
      final container = plannerContainer(tasks: tasks);
      addTearDown(container.dispose);
      final result = await container
          .read(smartPlannerQueryControllerProvider)
          .requestPlanningGuidance(
            energy: .5,
            emotion: emotion,
            notes: 'Plan the release checklist',
            history: const [],
            previousSavedNotes: null,
          );
      expect(result.plannerResponse.recommendedKind, PlannerOptionKind.minimum);
      expect(result.plannerResponse.recommendedOption.estimatedMinutes, 5);
      expect(
        result.plannerResponse.recommendationReason,
        contains('smaller reversible start'),
      );
      expect(tasks.writeCalls, 0);
    });
  }

  for (final status in RhythmPeriodStatus.values) {
    test(
      'rhythm period ${status.name} changes the planning response',
      () async {
        final rhythm = HabitEntity(
          id: 'walk',
          title: 'Morning walk',
          createdAt: DateTime.utc(2026, 8, 1),
          cadence: HabitCadence.weekly,
          targetCount: 3,
        );
        final container = plannerContainer(
          rhythms: [RhythmPlanningEntry(rhythm, '2026-08-24', status)],
        );
        addTearDown(container.dispose);
        final result = await container
            .read(smartPlannerQueryControllerProvider)
            .requestPlanningGuidance(
              energy: .5,
              emotion: null,
              notes: 'Plan my morning walk',
              history: const [],
              previousSavedNotes: null,
            );
        expect(result.request.context['focusedEvidenceKind'], 'daily_rhythm');
        expect(
          result.plannerResponse.isClarification,
          status != RhythmPeriodStatus.unrecorded,
        );
        if (status == RhythmPeriodStatus.unrecorded) {
          expect(
            result.plannerResponse.nextStep,
            contains('one remaining session'),
          );
          expect(
            result.plannerResponse.verifiedEvidence.join(' '),
            contains(
              'Individual repetitions and session durations are unknown',
            ),
          );
        } else {
          expect(result.plannerResponse.options, isEmpty);
          expect(result.plannerResponse.mattersMost, contains(status.name));
        }
      },
    );
  }

  test(
    'explicit selected note grounds linked work and caps every option',
    () async {
      final tasks = _MemoryTaskRepository([
        TaskEntity(
          id: 'linked',
          title: 'Release checklist',
          createdAt: DateTime.utc(2026, 8, 1),
          estimatedDuration: const Duration(minutes: 60),
        ),
      ]);
      final container = plannerContainer(
        tasks: tasks,
        selectedNote: NoteEntity(
          id: 'constraint',
          title: 'Capacity note',
          body: 'I only have 12 minutes',
          taskId: 'linked',
          createdAt: DateTime.utc(2026, 8, 1),
        ),
      );
      addTearDown(container.dispose);
      final result = await container
          .read(smartPlannerQueryControllerProvider)
          .requestPlanningGuidance(
            energy: .9,
            emotion: EmotionalState.engaged,
            notes: 'Help me choose a step',
            history: const [],
            previousSavedNotes: null,
          );
      expect(result.request.context['selectedNoteId'], 'constraint');
      expect(
        result.plannerResponse.options.every(
          (option) => option.estimatedMinutes <= 12,
        ),
        isTrue,
      );
      expect(result.plannerResponse.nextStep, contains('Release checklist'));
      expect(
        result.plannerResponse.verifiedEvidence.join(' '),
        contains('explicitly selected'),
      );
      expect(tasks.writeCalls, 0);
    },
  );

  test(
    'unreadable goal evidence is never reported as an empty account',
    () async {
      final container = plannerContainer(goals: _UnreadableGoals());
      addTearDown(container.dispose);
      final result = await container
          .read(smartPlannerQueryControllerProvider)
          .requestPlanningGuidance(
            energy: null,
            emotion: null,
            notes: 'Plan my next step',
            history: const [],
            previousSavedNotes: null,
          );
      expect(result.request.context['goalEvidenceReadSucceeded'], isFalse);
      expect(
        result.plannerResponse.verifiedEvidence.join(' '),
        contains('only partially available'),
      );
      expect(
        result.plannerResponse.verifiedEvidence.join(' '),
        isNot(contains('no active tasks or goals were found')),
      );
    },
  );

  test('Spanish selected-note capacity limits all proposed work', () async {
    final container = plannerContainer(
      selectedNote: NoteEntity(
        id: 'spanish',
        title: 'Tiempo disponible',
        body: 'Solo tengo 8 minutos',
        createdAt: DateTime.utc(2026, 8, 29),
      ),
    );
    addTearDown(container.dispose);
    final result = await container
        .read(smartPlannerQueryControllerProvider)
        .requestPlanningGuidance(
          energy: .9,
          emotion: null,
          notes: 'Help me choose a step',
          history: const [],
          previousSavedNotes: null,
        );
    expect(result.plannerResponse.options, isNotEmpty);
    expect(
      result.plannerResponse.options.every(
        (option) => option.estimatedMinutes <= 8,
      ),
      isTrue,
    );
  });

  test(
    'unresponsive supplementary rhythm data cannot stall planning',
    () async {
      final pending = Completer<List<RhythmPlanningEntry>>();
      final container = plannerContainer(rhythmRead: pending.future);
      addTearDown(container.dispose);
      final result = await container
          .read(smartPlannerQueryControllerProvider)
          .requestPlanningGuidance(
            energy: .5,
            emotion: null,
            notes: 'Organize my desk',
            history: const [],
            previousSavedNotes: null,
          )
          .timeout(const Duration(seconds: 5));
      expect(
        result.plannerResponse.verifiedEvidence.join(' '),
        contains('Daily Rhythm outcomes were unavailable'),
      );
      expect(result.plannerResponse.options, isNotEmpty);
      pending.complete(const []);
    },
  );

  PersonContextSignal contextSignal({
    required String id,
    required PersonContextKind kind,
    required String value,
    PersonContextConsent consent = PersonContextConsent.granted,
    PersonContextKnowledge knowledge = PersonContextKnowledge.known,
    PersonContextPurpose? purpose,
    DateTime? freshUntil,
  }) => PersonContextSignal(
    id: id,
    kind: kind,
    value: value,
    source: PersonContextSource.userAuthored,
    consent: consent,
    consentedAt: consent == PersonContextConsent.granted
        ? DateTime.utc(2026, 8, 29, 16)
        : DateTime.utc(2026, 8, 29, 15),
    withdrawnAt: consent == PersonContextConsent.withdrawn
        ? DateTime.utc(2026, 8, 29, 17)
        : null,
    purpose: purpose ?? PersonContextBehaviorPolicy.ruleFor(kind).purpose,
    surfaceScopes: const <PersonContextSurface>{
      PersonContextSurface.smartPlanner,
    },
    recordedAt: DateTime.utc(2026, 8, 29, 16),
    freshUntil: freshUntil ?? DateTime.utc(2026, 8, 30, 16),
    expiresAt: DateTime.utc(2026, 9, 30, 16),
    exportBehavior: PersonContextExportBehavior.include,
    deletionBehavior: PersonContextDeletionBehavior.userRemovable,
    knowledge: knowledge,
  );

  PersonContextView contextView(
    List<PersonContextSignal> signals, {
    String? accountScopeId,
  }) => PersonContextView(
    accountScopeId: accountScopeId ?? _plannerTestAccountScopeId,
    surface: PersonContextSurface.smartPlanner,
    purposes: operationalPersonContextPurposes,
    observedAt: DateTime.utc(2026, 8, 29, 18),
    signals: signals,
    unknownKinds: PersonContextKind.values.toSet().difference(
      signals.map((PersonContextSignal signal) => signal.kind).toSet(),
    ),
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
    expect(
      result.evidence,
      contains('Origin: deterministic on-device Planner V2.'),
    );
    result.request.validate();
    result.response.validateAgainst(result.request);
    expect(
      result.safetyReceipt.disposition,
      AssistantSafetyDisposition.approved,
    );
  });

  test(
    'current priority ranks saved evidence but cannot become the sole plan subject',
    () async {
      Future<SmartPlannerResult> requestFor(String priority) async {
        final ProviderContainer container = plannerContainer(
          personContext: contextView(<PersonContextSignal>[
            contextSignal(
              id: 'priority',
              kind: PersonContextKind.currentPriority,
              value: priority,
            ),
          ]),
        );
        addTearDown(container.dispose);
        return container
            .read(smartPlannerQueryControllerProvider)
            .requestPlanningGuidance(
              energy: 0.61,
              emotion: EmotionalState.calm,
              notes: 'Help me choose the next practical step.',
              history: const <Map<String, String>>[],
              previousSavedNotes: null,
            );
      }

      final SmartPlannerResult familyTime = await requestFor(
        'Protect family time tonight',
      );
      final SmartPlannerResult releaseNotes = await requestFor(
        'Prepare release notes first',
      );

      expect(
        familyTime.plannerResponse.mattersMost,
        isNot(contains('Protect family time tonight')),
      );
      expect(
        releaseNotes.plannerResponse.mattersMost,
        isNot(contains('Prepare release notes first')),
      );
      expect(
        familyTime.plannerResponse.options
            .expand(
              (PlannerOption option) => <String>[
                option.title,
                option.description,
              ],
            )
            .join(' '),
        isNot(contains('Protect family time tonight')),
      );
      expect(
        familyTime.plannerResponse.verifiedEvidence,
        contains(
          contains(
            'Verified person-context evidence: user-authored current priority',
          ),
        ),
      );
      expect(
        familyTime.plannerResponse.verifiedEvidence,
        contains(contains('not an inferred trait or identity')),
      );
      expect(familyTime.request.context['personContextStatus'], 'available');
      expect(familyTime.request.context['personContextSignalsUsed'], 1);
      expect(familyTime.request.context['personContextEvidenceKinds'], <String>[
        'currentPriority',
      ]);
    },
  );

  test('reported capacity caps every Planner option duration', () async {
    final ProviderContainer container = plannerContainer(
      personContext: contextView(<PersonContextSignal>[
        contextSignal(
          id: 'capacity',
          kind: PersonContextKind.presentCapacity,
          value: '10 minutes available today',
        ),
      ]),
    );
    addTearDown(container.dispose);

    final SmartPlannerResult result = await container
        .read(smartPlannerQueryControllerProvider)
        .requestPlanningGuidance(
          energy: 0.61,
          emotion: EmotionalState.calm,
          notes: 'Help me choose the next practical step.',
          history: const <Map<String, String>>[],
          previousSavedNotes: null,
        );

    expect(
      result.plannerResponse.options.map(
        (PlannerOption option) => option.estimatedMinutes,
      ),
      everyElement(lessThanOrEqualTo(10)),
    );
    expect(
      result.plannerResponse.adaptationReceipt.adjustments,
      contains(
        'Applied your reported capacity limit of 10 minutes: no option exceeds it.',
      ),
    );
  });

  test(
    'query-bound revision invalidates displayed exact-match context but ignores unrelated changes',
    () {
      const String decisionText = 'Help plan the release manager review.';
      String revisionFor(PersonContextSignal signal) {
        final ProviderContainer container = plannerContainer(
          personContext: contextView(<PersonContextSignal>[signal]),
        );
        addTearDown(container.dispose);
        return container.read(
          smartPlannerPersonContextBehaviorRevisionForDecisionProvider(
            decisionText,
          ),
        );
      }

      final String relevant = revisionFor(
        contextSignal(
          id: 'role',
          kind: PersonContextKind.role,
          value: 'Release manager',
        ),
      );
      final String withdrawn = revisionFor(
        contextSignal(
          id: 'role',
          kind: PersonContextKind.role,
          value: 'Release manager',
          consent: PersonContextConsent.withdrawn,
        ),
      );
      final String unrelatedA = revisionFor(
        contextSignal(
          id: 'role-a',
          kind: PersonContextKind.role,
          value: 'Garden volunteer',
        ),
      );
      final String unrelatedB = revisionFor(
        contextSignal(
          id: 'role-b',
          kind: PersonContextKind.role,
          value: 'Choir volunteer',
        ),
      );

      expect(relevant, isNot(withdrawn));
      expect(unrelatedA, unrelatedB);
    },
  );

  test(
    'Planner uses policy precedence and exposes its decision trace',
    () async {
      final ProviderContainer container = plannerContainer(
        personContext: contextView(<PersonContextSignal>[
          contextSignal(
            id: 'priority',
            kind: PersonContextKind.currentPriority,
            value: 'Prepare release notes first',
          ),
          contextSignal(
            id: 'boundary',
            kind: PersonContextKind.boundary,
            value: 'Do not schedule over family dinner',
          ),
        ]),
      );
      addTearDown(container.dispose);

      final SmartPlannerResult result = await container
          .read(smartPlannerQueryControllerProvider)
          .requestPlanningGuidance(
            energy: 0.61,
            emotion: EmotionalState.calm,
            notes: 'Help me choose the next practical step.',
            history: const <Map<String, String>>[],
            previousSavedNotes: null,
          );

      expect(
        result.plannerResponse.mattersMost,
        contains('Do not schedule over family dinner'),
      );
      expect(result.request.context['personContextEvidenceKinds'], <String>[
        'boundary',
        'currentPriority',
      ]);
      final Map<String, Object?> trace =
          result.request.context['personContextDecisionTrace']!
              as Map<String, Object?>;
      final List<dynamic> used = trace['used']! as List<dynamic>;
      expect((used.first as Map<dynamic, dynamic>)['kind'], 'boundary');
      expect(trace['noContextBaseline'], isA<Map<String, Object?>>());
    },
  );

  test('Planner trace rejects evidence beyond its applied limit', () async {
    final ProviderContainer container = plannerContainer(
      personContext: contextView(<PersonContextSignal>[
        contextSignal(
          id: 'wording',
          kind: PersonContextKind.preferredSupportStyle,
          value: 'Keep the wording direct',
        ),
        contextSignal(
          id: 'priority',
          kind: PersonContextKind.currentPriority,
          value: 'Prepare release notes first',
        ),
        contextSignal(
          id: 'capacity',
          kind: PersonContextKind.presentCapacity,
          value: 'Use a short work block',
        ),
        contextSignal(
          id: 'commitment',
          kind: PersonContextKind.commitment,
          value: 'Keep the 4 PM appointment',
        ),
        contextSignal(
          id: 'boundary',
          kind: PersonContextKind.boundary,
          value: 'Do not schedule over family dinner',
        ),
      ]),
    );
    addTearDown(container.dispose);

    final SmartPlannerResult result = await container
        .read(smartPlannerQueryControllerProvider)
        .requestPlanningGuidance(
          energy: 0.61,
          emotion: EmotionalState.calm,
          notes: 'Help me choose the next practical step.',
          history: const <Map<String, String>>[],
          previousSavedNotes: null,
        );

    expect(result.request.context['personContextAvailableSignalCount'], 5);
    expect(result.request.context['personContextSignalsUsed'], 3);
    expect(result.request.context['personContextSignalsRejected'], 2);
    expect(result.request.context['personContextEvidenceKinds'], <String>[
      'boundary',
      'commitment',
      'presentCapacity',
    ]);
    final Map<String, Object?> trace =
        result.request.context['personContextDecisionTrace']!
            as Map<String, Object?>;
    final List<dynamic> rejected = trace['rejected']! as List<dynamic>;
    expect(
      rejected.map(
        (dynamic value) => (value as Map<dynamic, dynamic>)['reason'] as String,
      ),
      everyElement('consumerLimitExceeded'),
    );
  });

  test('null and valid-empty person context remain distinguishable', () async {
    final ProviderContainer unavailableContainer = plannerContainer();
    final ProviderContainer emptyContainer = plannerContainer(
      personContext: contextView(const <PersonContextSignal>[]),
    );
    addTearDown(unavailableContainer.dispose);
    addTearDown(emptyContainer.dispose);

    Future<SmartPlannerResult> request(ProviderContainer container) => container
        .read(smartPlannerQueryControllerProvider)
        .requestPlanningGuidance(
          energy: 0.5,
          emotion: EmotionalState.neutral,
          notes: 'Choose a practical next step.',
          history: const <Map<String, String>>[],
          previousSavedNotes: null,
        );

    final SmartPlannerResult unavailable = await request(unavailableContainer);
    final SmartPlannerResult knownEmpty = await request(emptyContainer);

    expect(unavailable.request.context['personContextStatus'], 'unavailable');
    expect(knownEmpty.request.context['personContextStatus'], 'known_empty');
    expect(
      unavailable.plannerResponse.verifiedEvidence,
      contains(
        'Person context was unavailable for Smart Planner and was not used.',
      ),
    );
    expect(
      knownEmpty.plannerResponse.verifiedEvidence,
      contains(
        'Person context checked for Smart Planner: no consented fresh signals were available.',
      ),
    );
  });

  test('person context from another account is unavailable', () async {
    final ProviderContainer container = plannerContainer(
      personContext: contextView(<PersonContextSignal>[
        contextSignal(
          id: 'priority',
          kind: PersonContextKind.currentPriority,
          value: 'Private other-account priority',
        ),
      ], accountScopeId: 'v2.other-account'),
    );
    addTearDown(container.dispose);

    final SmartPlannerResult result = await container
        .read(smartPlannerQueryControllerProvider)
        .requestPlanningGuidance(
          energy: 0.5,
          emotion: EmotionalState.neutral,
          notes: 'Choose a practical next step.',
          history: const <Map<String, String>>[],
          previousSavedNotes: null,
        );

    expect(result.request.context['personContextStatus'], 'unavailable');
    expect(result.message, isNot(contains('Private other-account priority')));
  });

  test('account transition during evidence read fails closed', () async {
    final _GatedTaskRepository tasks = _GatedTaskRepository();
    final ProviderContainer container = plannerContainer(tasks: tasks);
    addTearDown(container.dispose);
    final Future<SmartPlannerResult> pending = container
        .read(smartPlannerQueryControllerProvider)
        .requestPlanningGuidance(
          energy: 0.5,
          emotion: EmotionalState.neutral,
          notes: 'Choose a practical next step.',
          history: const <Map<String, String>>[],
          previousSavedNotes: null,
        );

    await tasks.started.future;
    container
        .read(authSessionBoundaryProvider.notifier)
        .begin(userId: 'other-account', isTransitioning: true);
    tasks.release();

    await expectLater(
      pending,
      throwsA(
        isA<StateError>().having(
          (StateError error) => error.message,
          'message',
          contains('account scope changed'),
        ),
      ),
    );
  });

  test(
    'unknown expired and withdrawn person signals never enter Planner evidence',
    () async {
      final ProviderContainer container = plannerContainer(
        personContext: contextView(<PersonContextSignal>[
          contextSignal(
            id: 'valid-priority',
            kind: PersonContextKind.currentPriority,
            value: 'Finish the consent review',
          ),
          contextSignal(
            id: 'unknown-role',
            kind: PersonContextKind.role,
            value: '',
            knowledge: PersonContextKnowledge.unknown,
          ),
          contextSignal(
            id: 'expired-boundary',
            kind: PersonContextKind.boundary,
            value: 'EXPIRED PRIVATE BOUNDARY',
            freshUntil: DateTime.utc(2026, 8, 29, 17),
          ),
          contextSignal(
            id: 'withdrawn-value',
            kind: PersonContextKind.value,
            value: 'WITHDRAWN PRIVATE VALUE',
            consent: PersonContextConsent.withdrawn,
          ),
        ]),
      );
      addTearDown(container.dispose);

      final SmartPlannerResult result = await container
          .read(smartPlannerQueryControllerProvider)
          .requestPlanningGuidance(
            energy: 0.5,
            emotion: EmotionalState.neutral,
            notes: 'Choose a practical next step.',
            history: const <Map<String, String>>[],
            previousSavedNotes: null,
          );
      final String visible = <String>[
        result.message,
        ...result.plannerResponse.verifiedEvidence,
      ].join('\n');

      expect(result.request.context['personContextSignalsUsed'], 1);
      expect(result.request.context['personContextSignalsRejected'], 3);
      expect(result.request.context['personContextEvidenceKinds'], <String>[
        'currentPriority',
      ]);
      final Map<String, Object?> trace =
          result.request.context['personContextDecisionTrace']!
              as Map<String, Object?>;
      final List<dynamic> rejected = trace['rejected']! as List<dynamic>;
      expect(
        rejected.map(
          (dynamic value) =>
              (value as Map<dynamic, dynamic>)['reason'] as String,
        ),
        containsAll(<String>['unknown', 'stale', 'consentWithdrawn']),
      );
      expect(visible, contains('Finish the consent review'));
      expect(visible, isNot(contains('EXPIRED PRIVATE BOUNDARY')));
      expect(visible, isNot(contains('WITHDRAWN PRIVATE VALUE')));
      expect(visible, isNot(contains('user-authored role')));
    },
  );

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

  test(
    'typed current priority grounds a generic request to the matching task, not the first unrelated task',
    () async {
      final _MemoryTaskRepository tasks = _MemoryTaskRepository(<TaskEntity>[
        TaskEntity(
          id: 'task-unrelated',
          title: 'File expenses',
          createdAt: DateTime.utc(2026, 8, 20),
          priority: 5,
        ),
        TaskEntity(
          id: 'task-release',
          title: 'Prepare release evidence',
          createdAt: DateTime.utc(2026, 8, 20),
          priority: 3,
        ),
      ]);
      final ProviderContainer container = plannerContainer(
        tasks: tasks,
        personContext: contextView(<PersonContextSignal>[
          contextSignal(
            id: 'priority-release',
            kind: PersonContextKind.currentPriority,
            value: 'Prepare release evidence first',
          ),
        ]),
      );
      addTearDown(container.dispose);

      final SmartPlannerResult result = await container
          .read(smartPlannerQueryControllerProvider)
          .requestPlanningGuidance(
            energy: 0.65,
            emotion: EmotionalState.calm,
            notes: 'What should I do next?',
            history: const <Map<String, String>>[],
            previousSavedNotes: null,
          );

      expect(result.plannerResponse.isClarification, isFalse);
      expect(result.request.context['positiveEvidenceRelevance'], isTrue);
      expect(result.request.context['storedEvidenceUsed'], isTrue);
      expect(
        result.plannerResponse.options.every(
          (PlannerOption option) =>
              option.description.contains('Prepare release evidence'),
        ),
        isTrue,
      );
      expect(result.message, isNot(contains('File expenses')));
      expect(tasks.writeCalls, 0);
    },
  );

  test(
    'wording-only context cannot become Planner subject or defeat relevance clarification',
    () async {
      final _MemoryTaskRepository tasks = _MemoryTaskRepository(<TaskEntity>[
        TaskEntity(
          id: 'task-release',
          title: 'Finish Play release checklist',
          createdAt: DateTime.utc(2026, 8, 20),
          priority: 5,
        ),
      ]);
      final ProviderContainer container = plannerContainer(
        tasks: tasks,
        personContext: contextView(<PersonContextSignal>[
          contextSignal(
            id: 'wording-only',
            kind: PersonContextKind.preferredSupportStyle,
            value: 'Use concise bullets',
          ),
        ]),
      );
      addTearDown(container.dispose);

      final SmartPlannerResult result = await container
          .read(smartPlannerQueryControllerProvider)
          .requestPlanningGuidance(
            energy: 0.65,
            emotion: EmotionalState.calm,
            notes: 'Help me plan groceries for dinner.',
            history: const <Map<String, String>>[],
            previousSavedNotes: null,
          );

      final String substantiveResponse = <String>[
        result.plannerResponse.whatIHeard,
        result.plannerResponse.mattersMost,
        ...result.plannerResponse.options.expand(
          (PlannerOption option) => <String>[
            option.title,
            option.description,
            option.tradeoff,
          ],
        ),
        result.plannerResponse.recommendationReason,
        result.plannerResponse.nextStep,
        result.plannerResponse.usefulQuestion ?? '',
      ].join('\n');

      expect(result.plannerResponse.isClarification, isTrue);
      expect(result.request.context['focusedEvidenceKind'], 'none');
      expect(result.request.context['positiveEvidenceRelevance'], isFalse);
      expect(result.request.context['personContextSignalsUsed'], 1);
      expect(result.request.context['personContextChangedFields'], <String>[
        'responseWording',
      ]);
      expect(substantiveResponse, isNot(contains('Use concise bullets')));
      expect(substantiveResponse, isNot(contains('preferred support style')));
      expect(tasks.writeCalls, 0);
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

  test(
    'unmatched saved evidence asks exactly one question and attaches nothing',
    () async {
      final _MemoryTaskRepository tasks = _MemoryTaskRepository(<TaskEntity>[
        TaskEntity(
          id: 'task-release',
          title: 'Finish Play release checklist',
          createdAt: DateTime.utc(2026, 8, 20),
          priority: 5,
        ),
      ]);
      final ProviderContainer container = plannerContainer(tasks: tasks);
      addTearDown(container.dispose);

      final SmartPlannerResult result = await container
          .read(smartPlannerQueryControllerProvider)
          .requestPlanningGuidance(
            energy: 0.6,
            emotion: EmotionalState.calm,
            notes: 'Help me plan groceries for dinner.',
            history: const <Map<String, String>>[],
            previousSavedNotes: null,
          );

      expect(result.plannerResponse.isClarification, isTrue);
      expect(result.plannerResponse.options, isEmpty);
      expect(result.plannerResponse.controls, isEmpty);
      expect('?'.allMatches(result.plannerResponse.usefulQuestion!).length, 1);
      expect(result.message, isNot(contains('Finish Play release checklist')));
      expect(result.request.context['storedEvidenceUsed'], isFalse);
      expect(result.request.context['positiveEvidenceRelevance'], isFalse);
      expect(tasks.writeCalls, 0);
    },
  );

  test(
    'protected concerns never redirect into an unrelated saved task',
    () async {
      const List<String> prompts = <String>[
        'My father died and I am grieving.',
        'My relationship with my partner is falling apart.',
        'My partner is abusive and controlling.',
      ];
      for (final String prompt in prompts) {
        final ProviderContainer container = plannerContainer(
          tasks: _MemoryTaskRepository(<TaskEntity>[
            TaskEntity(
              id: 'task-release',
              title: 'Finish Play release checklist',
              createdAt: DateTime.utc(2026, 8, 20),
              priority: 5,
            ),
          ]),
        );
        addTearDown(container.dispose);

        final SmartPlannerResult result = await container
            .read(smartPlannerQueryControllerProvider)
            .requestPlanningGuidance(
              energy: 0.4,
              emotion: EmotionalState.negative,
              notes: prompt,
              history: const <Map<String, String>>[],
              previousSavedNotes: null,
              supportivePauseReason:
                  'Pausing productivity guidance for this concern.',
              supportiveQuestion: 'Would you like support right now?',
            );

        expect(result.plannerResponse.isClarification, isTrue);
        expect(result.plannerResponse.options, isEmpty);
        expect(
          '?'.allMatches(result.plannerResponse.usefulQuestion!).length,
          1,
        );
        expect(
          result.message,
          isNot(contains('Finish Play release checklist')),
        );
      }
    },
  );

  test(
    'matching current operating receipt grounds guidance read-only',
    () async {
      final ProviderContainer container = plannerContainer(
        operatingReceipt: _operatingReceipt(),
      );
      addTearDown(container.dispose);

      final SmartPlannerResult result = await container
          .read(smartPlannerQueryControllerProvider)
          .requestPlanningGuidance(
            energy: 0.65,
            emotion: EmotionalState.calm,
            notes: 'Help me prepare the release evidence.',
            history: const <Map<String, String>>[],
            previousSavedNotes: null,
          );

      expect(result.plannerResponse.isClarification, isFalse);
      expect(result.request.context['operatingReceiptUsed'], isTrue);
      expect(
        result.request.context['focusedEvidenceKind'],
        'operating_receipt',
      );
      expect(
        result.plannerResponse.verifiedEvidence,
        contains(contains('saved planning recommendation matched')),
      );
      expect(
        result.plannerResponse.whatIHeard,
        contains('saved planning recommendation "Prepare release evidence"'),
      );
      expect(
        <String>[
          result.message,
          result.plannerResponse.whatIHeard,
          result.plannerResponse.recommendationReason,
          ...result.plannerResponse.verifiedEvidence,
        ].join('\n').toLowerCase(),
        isNot(contains('operating receipt')),
      );
      expect(
        result.plannerResponse.options.every(
          (PlannerOption option) =>
              option.description.contains('Prepare release evidence'),
        ),
        isTrue,
      );
    },
  );

  test(
    'Planner memory recall keeps exact surface purpose and consent boundary',
    () async {
      final ProviderContainer container = plannerContainer(
        plannerMemories: <MemoryEntity>[
          _plannerMemory(id: 'allowed', text: 'Prefer one small next step.'),
          _plannerMemory(
            id: 'wrong-surface',
            text: 'CREATOR MEMORY MUST NOT APPEAR',
            surface: MemorySurface.creator,
          ),
          _plannerMemory(
            id: 'wrong-purpose',
            text: 'OUTCOME MEMORY MUST NOT APPEAR',
            purpose: MemoryPurpose.outcomeLearning,
          ),
          _plannerMemory(
            id: 'withdrawn',
            text: 'WITHDRAWN MEMORY MUST NOT APPEAR',
            consent: MemoryConsentStatus.withdrawn,
          ),
        ],
      );
      addTearDown(container.dispose);

      final SmartPlannerResult result = await container
          .read(smartPlannerQueryControllerProvider)
          .requestPlanningGuidance(
            energy: 0.6,
            emotion: EmotionalState.calm,
            notes: 'Help me choose one practical step.',
            history: const <Map<String, String>>[],
            previousSavedNotes: null,
          );
      final String visible = <String>[
        result.message,
        ...result.plannerResponse.verifiedEvidence,
      ].join('\n');

      expect(result.request.context['plannerMemorySignalsUsed'], 1);
      expect(visible, contains('Prefer one small next step.'));
      expect(visible, isNot(contains('CREATOR MEMORY MUST NOT APPEAR')));
      expect(visible, isNot(contains('OUTCOME MEMORY MUST NOT APPEAR')));
      expect(visible, isNot(contains('WITHDRAWN MEMORY MUST NOT APPEAR')));
    },
  );

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

  test(
    'empty check-in and follow-up do not turn generated prompt into a task',
    () async {
      final container = plannerContainer();
      addTearDown(container.dispose);
      final controller = container.read(smartPlannerQueryControllerProvider);
      final initial = await controller.requestPlanningGuidance(
        energy: null,
        emotion: null,
        notes: '',
        history: const [],
        previousSavedNotes: null,
      );
      final followUp = await controller.requestFollowUpResult(
        input: 'Make this smaller',
        energy: null,
        emotion: null,
        reflection: '',
        history: [
          {'role': 'user', 'content': initial.prompt},
          {'role': 'assistant', 'content': initial.message},
        ],
      );
      for (final response in [
        initial.plannerResponse,
        followUp.plannerResponse,
      ]) {
        for (final option in response.options) {
          expect(option.description, isNot(contains('Give me a practical')));
          expect(
            option.description,
            isNot(contains('current energy and emotion')),
          );
          expect(option.description.trim(), isNotEmpty);
        }
        expect(response.nextStep, isNot(contains('Give me a practical')));
      }
      expect(
        initial.plannerResponse.nextStep,
        contains('one task you choose for today'),
      );
    },
  );

  test(
    'declining saved context advances and keeps the next request independent',
    () async {
      final tasks = _MemoryTaskRepository([
        TaskEntity(
          id: 'release',
          title: 'Prepare release evidence',
          createdAt: DateTime.utc(2026, 8, 20),
        ),
      ]);
      final container = plannerContainer(
        tasks: tasks,
        operatingReceipt: _operatingReceipt(),
      );
      addTearDown(container.dispose);
      final controller = container.read(smartPlannerQueryControllerProvider);
      final initial = await controller.requestPlanningGuidance(
        energy: null,
        emotion: null,
        notes: '',
        history: const [],
        previousSavedNotes: null,
      );
      expect(initial.plannerResponse.isClarification, isTrue);
      for (final answer in ['None', 'No thanks', 'Neither.']) {
        final history = [
          {'role': 'user', 'content': initial.prompt},
          {'role': 'assistant', 'content': initial.message},
        ];
        final declined = await controller.requestFollowUpResult(
          input: answer,
          energy: null,
          emotion: null,
          reflection: '',
          history: history,
        );
        expect(
          declined.plannerResponse.isClarification,
          isFalse,
          reason: answer,
        );
        expect(declined.plannerResponse.options, hasLength(3));
        expect(
          declined.plannerResponse.nextStep,
          contains('one task you choose for today'),
        );
        history.addAll([
          {'role': 'user', 'content': answer},
          {'role': 'assistant', 'content': declined.message},
        ]);
        final explicit = await controller.requestFollowUpResult(
          input: 'Help me organize my desk for 10 minutes today',
          energy: null,
          emotion: null,
          reflection: '',
          history: history,
        );
        expect(explicit.plannerResponse.isClarification, isFalse);
        expect(explicit.plannerResponse.nextStep, contains('organize my desk'));
        expect(explicit.message, isNot(contains('Prepare release evidence')));
        expect(explicit.request.context['storedEvidenceUsed'], isFalse);
      }
      expect(tasks.writeCalls, 0);
    },
  );

  test('a concrete follow-up replaces the previous planning target', () async {
    final container = plannerContainer(operatingReceipt: _operatingReceipt());
    addTearDown(container.dispose);
    final result = await container
        .read(smartPlannerQueryControllerProvider)
        .requestFollowUpResult(
          input: 'Help me organize my desk for 10 minutes today',
          energy: null,
          emotion: null,
          reflection: '',
          history: const [
            {'role': 'user', 'content': 'Prepare release evidence'},
            {
              'role': 'assistant',
              'content':
                  'Which saved task or goal, if any, should this plan support?',
            },
          ],
        );
    expect(result.plannerResponse.isClarification, isFalse);
    expect(result.plannerResponse.nextStep, contains('organize my desk'));
    expect(result.request.context['operatingReceiptUsed'], isFalse);
    expect(
      result.message,
      isNot(
        contains('saved planning recommendation "Prepare release evidence"'),
      ),
    );
  });

  test(
    'independent planning retains consented capacity and can opt back into saved work',
    () async {
      final container = plannerContainer(
        operatingReceipt: _operatingReceipt(),
        personContext: contextView([
          contextSignal(
            id: 'capacity',
            kind: PersonContextKind.presentCapacity,
            value: 'I have 10 minutes available.',
          ),
        ]),
      );
      addTearDown(container.dispose);
      final controller = container.read(smartPlannerQueryControllerProvider);
      const history = [
        {
          'role': 'assistant',
          'content':
              'Which saved task or goal, if any, should this plan support?',
        },
        {'role': 'user', 'content': 'None'},
        {'role': 'assistant', 'content': 'Choose a task for today.'},
      ];
      final independent = await controller.requestFollowUpResult(
        input: 'Help me organize my desk',
        energy: 0.9,
        emotion: null,
        reflection: '',
        history: history,
      );
      expect(independent.plannerResponse.isClarification, isFalse);
      expect(
        independent.plannerResponse.adaptationReceipt.adjustments,
        contains(contains('capacity limit of 10 minutes')),
      );
      for (final limit in [5, 30]) {
        final limited = await controller.requestFollowUpResult(
          input: 'Help me organize my desk in $limit minutes',
          energy: 0.9,
          emotion: null,
          reflection: '',
          history: history,
        );
        expect(
          limited.plannerResponse.options.map((o) => o.estimatedMinutes),
          everyElement(lessThanOrEqualTo(limit < 10 ? limit : 10)),
        );
      }
      final saved = await controller.requestFollowUpResult(
        input:
            'Use the saved planning recommendation to prepare release evidence',
        energy: null,
        emotion: null,
        reflection: '',
        history: history,
      );
      expect(saved.request.context['operatingReceiptUsed'], isTrue);
    },
  );

  test(
    'generic receipt rationale does not replace a concrete request',
    () async {
      final container = plannerContainer(
        operatingReceipt: _operatingReceipt(
          recommendedAction: 'Capture one actionable task in Creator.',
          rationale: 'Create a useful action for today.',
        ),
      );
      addTearDown(container.dispose);
      final result = await container
          .read(smartPlannerQueryControllerProvider)
          .requestFollowUpResult(
            input: 'Help me organize my desk for 10 minutes today',
            energy: null,
            emotion: null,
            reflection: '',
            history: const [],
          );
      expect(result.request.context['operatingReceiptUsed'], isFalse);
      expect(
        result.message,
        isNot(
          contains(
            'saved planning recommendation "Capture one actionable task',
          ),
        ),
      );
    },
  );

  test(
    'explicit request time limits cap every option without saved context',
    () {
      final container = plannerContainer();
      addTearDown(container.dispose);
      final controller = container.read(smartPlannerQueryControllerProvider);
      for (final input in [
        'Help me organize my desk in 10 minutes',
        'Help me organize my desk for 10 min',
        'I only have 10 minutes to organize my desk',
        'I have only 10 minutes to organize my desk',
      ]) {
        final response = controller.buildPlannerResponse(
          input: input,
          energy: null,
          emotion: null,
          contextWasProvided: true,
        );
        expect(response.options, hasLength(3));
        expect(
          response.options.map((option) => option.estimatedMinutes),
          everyElement(lessThanOrEqualTo(10)),
          reason: input,
        );
        expect(
          response.adaptationReceipt.adjustments,
          contains(contains('requested time limit of 10 minutes')),
        );
        expect(
          response.recommendationReason,
          isNot(contains('No current capacity')),
        );
      }
    },
  );

  test(
    'follow-up time limits stay with the subject and explicit changes win',
    () {
      final container = plannerContainer();
      addTearDown(container.dispose);
      final controller = container.read(smartPlannerQueryControllerProvider);
      const history = [
        {'role': 'user', 'content': 'Organize my desk in 10 minutes'},
        {'role': 'assistant', 'content': 'Choose one useful cycle.'},
      ];
      PlannerV2Response response(String input) =>
          controller.buildPlannerResponse(
            input: input,
            energy: null,
            emotion: null,
            contextWasProvided: true,
            history: history,
            isFollowUp: true,
          );
      expect(
        response(
          'Make that more specific',
        ).options.map((o) => o.estimatedMinutes),
        everyElement(lessThanOrEqualTo(10)),
      );
      expect(
        response(
          'I have 5 minutes for that',
        ).options.map((o) => o.estimatedMinutes),
        everyElement(lessThanOrEqualTo(5)),
      );
      expect(
        response('Help me write a letter').recommendedOption.estimatedMinutes,
        greaterThan(10),
      );
      expect(
        response(
          'I spent 5 minutes on my desk yesterday',
        ).recommendedOption.estimatedMinutes,
        greaterThan(5),
      );
      expect(
        response(
          'I do not have 10 minutes available',
        ).recommendedOption.estimatedMinutes,
        greaterThan(10),
      );
    },
  );

  test(
    'repeated referential follow-ups preserve the target and latest time limit',
    () {
      final container = plannerContainer();
      addTearDown(container.dispose);
      final response = container
          .read(smartPlannerQueryControllerProvider)
          .buildPlannerResponse(
            input: 'Can you make that more specific?',
            energy: null,
            emotion: null,
            contextWasProvided: true,
            isFollowUp: true,
            history: const [
              {'role': 'user', 'content': 'Organize my desk in 10 minutes'},
              {'role': 'assistant', 'content': 'Choose one useful cycle.'},
              {'role': 'user', 'content': 'I have 5 minutes for that'},
              {'role': 'assistant', 'content': 'Keep it bounded.'},
              {'role': 'user', 'content': 'Make that easier'},
              {'role': 'assistant', 'content': 'Use the smallest step.'},
            ],
          );
      expect(response.nextStep, contains('Organize my desk'));
      expect(
        response.options.map((o) => o.estimatedMinutes),
        everyElement(lessThanOrEqualTo(5)),
      );
    },
  );

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
    final String localizations = File(
      'lib/l10n/chronospark_localizations.dart',
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
      localizations,
      contains(
        'Your words and check-in stay ephemeral. A local decision receipt may record which guidance was shown or used. Nothing else is saved unless you explicitly remember a preference.',
      ),
    );
    expect(source, contains('routine.ephemeralNotice'));
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

  test(
    'supportive distress returns one question without reading saved work',
    () async {
      final _MemoryTaskRepository tasks = _MemoryTaskRepository();
      final _MemoryGoalRepository goals = _MemoryGoalRepository();
      final ProviderContainer container = plannerContainer(
        tasks: tasks,
        goals: goals,
      );
      addTearDown(container.dispose);
      final SmartPlannerQueryController controller = container.read(
        smartPlannerQueryControllerProvider,
      );

      final SmartPlannerResult result = await controller
          .requestPlanningGuidance(
            energy: 0.2,
            emotion: EmotionalState.anxious,
            notes: 'I am panicking and losing control',
            history: const <Map<String, String>>[],
            previousSavedNotes: null,
            supportivePauseReason:
                'Pausing productivity guidance because this sounds urgent.',
            supportiveQuestion: 'Would you like support right now?',
          );

      expect(result.plannerResponse.isClarification, isTrue);
      expect(result.plannerResponse.options, isEmpty);
      expect(result.plannerResponse.usefulQuestion, contains('Would you like'));
      expect(tasks.readCalls, 0);
      expect(tasks.writeCalls, 0);
      expect(goals.readCalls, 0);
      expect(goals.writeCalls, 0);
      expect(
        result.request.context['emotionalSafetyRoute'],
        'supportive_distress',
      );
      expect(result.request.context['storedEvidenceUsed'], isFalse);
    },
  );

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

class _ImmediateBetaOptIn extends AssistantBetaOptInNotifier {
  @override
  Future<bool> build() async => false;
}

OperatingDecisionReceipt _operatingReceipt({
  String recommendedAction = 'Prepare release evidence',
  String rationale = 'The current launch gate needs verified local evidence.',
}) => OperatingDecisionReceipt(
  decisionId: 'receipt-release',
  subjectId: null,
  recommendedAction: recommendedAction,
  rationale: rationale,
  whyItMatters: 'A verified release decision is the current priority.',
  consequenceOfDelay: 'The release decision remains unresolved.',
  generatedAt: DateTime.utc(2026, 8, 29, 17),
  expiresAt: DateTime.utc(2026, 8, 29, 21),
  confidence: OperatingConfidence.moderate,
  evidence: <OperatingEvidence>[
    OperatingEvidence(
      code: 'release-check',
      description: 'Release evidence remains incomplete.',
      kind: OperatingEvidenceKind.observed,
      recordedAt: DateTime.utc(2026, 8, 29, 17),
      source: 'local_release_gate',
    ),
  ],
  actionIntent: const OperatingActionIntent(
    id: 'open-creator',
    type: OperatingActionType.openCreator,
    label: 'Review in Creator',
    destination: 'creator',
    requiresConfirmation: true,
  ),
  sourceRevisions: const <String, String>{'release': 'r1'},
  modelVersion: 'operating-receipt-test-v1',
);

MemoryEntity _plannerMemory({
  required String id,
  required String text,
  MemorySurface surface = MemorySurface.smartPlanner,
  MemoryPurpose purpose = MemoryPurpose.guidancePreference,
  MemoryConsentStatus consent = MemoryConsentStatus.granted,
}) => MemoryEntity(
  id: id,
  text: text,
  date: DateTime.utc(2026, 8, 29, 16),
  category: MemoryCategory.planningGuidancePreference,
  accountScopeId: _plannerTestAccountScopeId,
  sourceSurface: surface,
  purpose: purpose,
  sensitivity: MemorySensitivity.standard,
  consentStatus: consent,
  consentedAt: DateTime.utc(2026, 8, 29, 16),
  expiresAt: DateTime.utc(2026, 9, 29, 16),
  provenance: 'test',
  whyStored: 'test',
);

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

class _GatedTaskRepository extends _MemoryTaskRepository {
  final Completer<void> started = Completer<void>();
  final Completer<void> _release = Completer<void>();

  @override
  Future<List<TaskEntity>> getAllTasks() async {
    readCalls += 1;
    if (!started.isCompleted) started.complete();
    await _release.future;
    return List<TaskEntity>.from(_tasks);
  }

  void release() {
    if (!_release.isCompleted) _release.complete();
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

class _UnreadableGoals extends _MemoryGoalRepository implements GoalReadHealth {
  @override
  bool get lastReadCorrupted => true;
}
