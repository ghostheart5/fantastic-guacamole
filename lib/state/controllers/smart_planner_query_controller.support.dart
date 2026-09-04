part of 'smart_planner_query_controller.dart';

final class _PlannerConversationContext {
  const _PlannerConversationContext({
    required this.input,
    required this.searchText,
    required this.subject,
    required this.priorSubject,
    required this.historyTurnsUsed,
    required this.isFollowUp,
  });

  factory _PlannerConversationContext.resolve({
    required String input,
    required List<Map<String, String>> history,
    String? reflection,
    required bool isFollowUp,
  }) {
    final String normalizedInput = input.trim();
    final List<String> priorUserTurns = history
        .where((Map<String, String> turn) => turn['role'] == 'user')
        .map((Map<String, String> turn) => turn['content']?.trim() ?? '')
        .where((String content) => content.isNotEmpty)
        .map(
          (String content) =>
              SmartPlannerQueryController._condense(content, maxLength: 180),
        )
        .toList(growable: true);
    final String normalizedReflection = reflection?.trim() ?? '';
    if (normalizedReflection.isNotEmpty &&
        !priorUserTurns.contains(normalizedReflection) &&
        normalizedReflection != normalizedInput) {
      priorUserTurns.insert(
        0,
        SmartPlannerQueryController._condense(
          normalizedReflection,
          maxLength: 180,
        ),
      );
    }
    final List<String> boundedPrior = priorUserTurns.length > 4
        ? priorUserTurns.sublist(priorUserTurns.length - 4)
        : priorUserTurns;
    final String priorSubject = boundedPrior.isEmpty
        ? ''
        : SmartPlannerQueryController._condense(
            boundedPrior.last,
            maxLength: 72,
          );
    final String subject = isFollowUp && priorSubject.isNotEmpty
        ? priorSubject
        : normalizedInput.isEmpty
        ? 'finding one useful next move'
        : SmartPlannerQueryController._condense(normalizedInput, maxLength: 72);
    return _PlannerConversationContext(
      input: normalizedInput,
      searchText: <String>[
        ...boundedPrior,
        normalizedInput,
      ].where((String value) => value.isNotEmpty).join(' '),
      subject: subject,
      priorSubject: priorSubject,
      historyTurnsUsed: boundedPrior.length,
      isFollowUp: isFollowUp,
    );
  }

  final String input;
  final String searchText;
  final String subject;
  final String priorSubject;
  final int historyTurnsUsed;
  final bool isFollowUp;

  String whatIHeard({
    required bool contextWasProvided,
    required _PlannerEvidence evidence,
  }) {
    final String? focus = evidence.focusSubject;
    if (isFollowUp) {
      final String followUp = SmartPlannerQueryController._condense(
        input,
        maxLength: 72,
      );
      final String connectedTo =
          focus ??
          (priorSubject.isEmpty ? 'your earlier plan' : '"$priorSubject"');
      return 'You are following up on $connectedTo: $followUp.';
    }
    if (focus != null) {
      return 'You want a workable next move for $focus.';
    }
    return contextWasProvided
        ? 'You want a workable way forward on: $subject.'
        : 'You want a practical check-in that fits your current capacity.';
  }

  String clarificationSummary({required bool contextWasProvided}) {
    if (isFollowUp) {
      return 'You are clarifying what kind of support would fit: ${SmartPlannerQueryController._condense(input, maxLength: 96)}.';
    }
    return contextWasProvided
        ? 'You want support with: ${SmartPlannerQueryController._condense(subject, maxLength: 96)}.'
        : 'You want a practical check-in, but the right planning target is not clear yet.';
  }

  String evidenceSummary({required bool contextWasProvided}) {
    if (historyTurnsUsed > 0) {
      return 'Used $historyTurnsUsed prior user conversation turn(s) for this response only; Planner did not save them.';
    }
    return contextWasProvided
        ? 'Planning context was supplied for this check-in; it was not saved as a reflection or memory.'
        : 'No planning context or prior user turn was supplied.';
  }
}

final class _PlannerEvidence {
  const _PlannerEvidence.empty()
    : activeTasks = const <TaskEntity>[],
      activeGoals = const <GoalEntity>[],
      focusTask = null,
      focusGoal = null,
      taskReadSucceeded = true,
      goalReadSucceeded = true,
      focusTaskIsUrgent = false,
      personContext = const _PlannerPersonContextEvidence.unavailable(),
      operatingReceipt = const _PlannerOperatingReceiptEvidence.unavailable(),
      plannerMemory = const _PlannerMemoryEvidence.empty();

  _PlannerEvidence({
    required List<TaskEntity> activeTasks,
    required List<GoalEntity> activeGoals,
    required this.focusTask,
    required this.focusGoal,
    required this.taskReadSucceeded,
    required this.goalReadSucceeded,
    required this.focusTaskIsUrgent,
    required this.personContext,
    required this.operatingReceipt,
    required this.plannerMemory,
  }) : activeTasks = List<TaskEntity>.unmodifiable(activeTasks),
       activeGoals = List<GoalEntity>.unmodifiable(activeGoals);

  factory _PlannerEvidence.resolve({
    required List<TaskEntity> tasks,
    required List<GoalEntity> goals,
    required String searchText,
    required DateTime now,
    required bool taskReadSucceeded,
    required bool goalReadSucceeded,
    required PersonContextView? personContext,
    required String accountScopeId,
    required OperatingDecisionReceipt? operatingReceipt,
    required List<MemoryEntity> plannerMemories,
  }) {
    final List<TaskEntity> activeTasks = tasks
        .where((TaskEntity task) => task.isActive)
        .toList(growable: true);
    final List<GoalEntity> activeGoals = goals
        .where((GoalEntity goal) => goal.isActive)
        .toList(growable: true);
    final _PlannerPersonContextEvidence resolvedPersonContext =
        _PlannerPersonContextEvidence.resolve(
          personContext,
          now: now,
          accountScopeId: accountScopeId,
          decisionText: searchText,
        );
    final Set<String> terms = _plannerTerms(searchText);
    activeTasks.sort(
      (TaskEntity left, TaskEntity right) =>
          _compareTasks(left, right, terms: terms, now: now),
    );
    activeGoals.sort(
      (GoalEntity left, GoalEntity right) =>
          _compareGoals(left, right, terms: terms, now: now),
    );

    final TaskEntity? matchedTask = activeTasks.isEmpty
        ? null
        : activeTasks.first;
    final GoalEntity? matchedGoal = activeGoals.isEmpty
        ? null
        : activeGoals.first;
    final int taskMatch = matchedTask == null
        ? 0
        : _taskTextMatch(matchedTask, terms);
    final int goalMatch = matchedGoal == null
        ? 0
        : _goalTextMatch(matchedGoal, terms);

    TaskEntity? focusTask;
    GoalEntity? focusGoal;
    if (goalMatch > taskMatch && goalMatch > 0) {
      focusGoal = matchedGoal;
      final List<TaskEntity> linkedTasks = activeTasks
          .where((TaskEntity task) => task.goalId == focusGoal?.id)
          .toList(growable: false);
      if (linkedTasks.isNotEmpty) {
        focusTask = linkedTasks.first;
      }
    } else if (matchedTask != null && taskMatch > 0) {
      focusTask = matchedTask;
      for (final GoalEntity goal in activeGoals) {
        if (goal.id == focusTask.goalId) {
          focusGoal = goal;
          break;
        }
      }
    } else {
      final _PlannerPersonContextSignal? rankingFocus =
          resolvedPersonContext.rankingFocus;
      final Set<String> contextTerms = rankingFocus == null
          ? const <String>{}
          : _plannerTerms(rankingFocus.value);
      int bestContextMatch = 0;
      for (final TaskEntity task in activeTasks) {
        final int match = _taskTextMatch(task, contextTerms);
        if (match <= bestContextMatch) continue;
        bestContextMatch = match;
        focusTask = task;
      }
      if (bestContextMatch == 0) {
        focusTask = null;
      } else {
        for (final GoalEntity goal in activeGoals) {
          if (goal.id == focusTask?.goalId) {
            focusGoal = goal;
            break;
          }
        }
      }
    }

    final DateTime? focusTime = focusTask == null
        ? null
        : focusTask.dueDate ?? focusTask.scheduledFor;
    return _PlannerEvidence(
      activeTasks: activeTasks,
      activeGoals: activeGoals,
      focusTask: focusTask,
      focusGoal: focusGoal,
      taskReadSucceeded: taskReadSucceeded,
      goalReadSucceeded: goalReadSucceeded,
      personContext: resolvedPersonContext,
      operatingReceipt: _PlannerOperatingReceiptEvidence.resolve(
        operatingReceipt,
        searchText: searchText,
        now: now,
      ),
      plannerMemory: _PlannerMemoryEvidence.resolve(plannerMemories, now: now),
      focusTaskIsUrgent:
          focusTime != null &&
          !focusTime.isAfter(now.add(const Duration(days: 1))),
    );
  }

  final List<TaskEntity> activeTasks;
  final List<GoalEntity> activeGoals;
  final TaskEntity? focusTask;
  final GoalEntity? focusGoal;
  final bool taskReadSucceeded;
  final bool goalReadSucceeded;
  final bool focusTaskIsUrgent;
  final _PlannerPersonContextEvidence personContext;
  final _PlannerOperatingReceiptEvidence operatingReceipt;
  final _PlannerMemoryEvidence plannerMemory;

  bool get hasStoredEvidence =>
      activeTasks.isNotEmpty || activeGoals.isNotEmpty;

  bool get hasMatchedStoredEvidence => focusTask != null || focusGoal != null;

  bool get hasPositiveGrounding =>
      hasMatchedStoredEvidence ||
      operatingReceipt.focus != null ||
      personContext.planningFocus != null;

  bool get hasAvailableGroundingEvidence =>
      hasStoredEvidence ||
      operatingReceipt.wasAvailable ||
      personContext.planningFocus != null;

  bool get requiresClarification =>
      hasAvailableGroundingEvidence && !hasPositiveGrounding;

  String get domainAdaptationSummary {
    if (hasMatchedStoredEvidence) {
      return 'Used only saved task or goal evidence with a positive text relevance match.';
    }
    if (personContext.planningFocus != null) {
      return 'Used only consented, fresh Person Context with typed or positive-text relevance to this planning request.';
    }
    if (hasStoredEvidence) {
      return 'Active saved tasks or goals were present, but none had positive relevance to this check-in.';
    }
    return 'No active saved task or goal was available to ground this check-in.';
  }

  String? get focusSubject {
    final TaskEntity? task = focusTask;
    if (task != null) {
      return 'saved task "${SmartPlannerQueryController._safeEvidenceTitle(task.title)}"';
    }
    final GoalEntity? goal = focusGoal;
    if (goal != null) {
      return 'saved goal "${SmartPlannerQueryController._safeEvidenceTitle(goal.title)}"';
    }
    final OperatingDecisionReceipt? receipt = operatingReceipt.focus;
    if (receipt != null) {
      return 'saved planning recommendation "${SmartPlannerQueryController._safeEvidenceTitle(receipt.recommendedAction)}"';
    }
    return personContext.planningFocus?.subject;
  }

  String? get mattersMost {
    final TaskEntity? task = focusTask;
    if (task != null) {
      return 'Making a credible next move on saved task "${SmartPlannerQueryController._safeEvidenceTitle(task.title)}" without exceeding your reported capacity.';
    }
    final GoalEntity? goal = focusGoal;
    if (goal != null) {
      return 'Turning saved goal "${SmartPlannerQueryController._safeEvidenceTitle(goal.title)}" into observable progress.';
    }
    final OperatingDecisionReceipt? receipt = operatingReceipt.focus;
    if (receipt != null) {
      return SmartPlannerQueryController._condense(
        receipt.whyItMatters,
        maxLength: 180,
      );
    }
    return personContext.planningFocus?.mattersMost;
  }

  Map<String, Object?> get requestContext => <String, Object?>{
    'storedEvidenceUsed': hasMatchedStoredEvidence,
    'storedEvidenceAvailable': hasStoredEvidence,
    'positiveEvidenceRelevance': hasPositiveGrounding,
    'activeTaskCount': activeTasks.length,
    'activeGoalCount': activeGoals.length,
    'focusedEvidenceKind': focusTask != null
        ? 'task'
        : focusGoal != null
        ? 'goal'
        : operatingReceipt.focus != null
        ? 'operating_receipt'
        : personContext.planningFocus != null
        ? 'person_context'
        : 'none',
    'taskEvidenceReadSucceeded': taskReadSucceeded,
    'goalEvidenceReadSucceeded': goalReadSucceeded,
    ...operatingReceipt.requestContext,
    ...plannerMemory.requestContext,
    ...personContext.requestContext,
  };

  List<String> verifiedEvidence(DateTime observedAt) {
    final List<String> evidence = <String>[];
    if (!taskReadSucceeded || !goalReadSucceeded) {
      evidence.add(
        'Saved planning evidence was only partially available for this check-in.',
      );
    }
    if (!hasStoredEvidence) {
      evidence.add(
        taskReadSucceeded && goalReadSucceeded
            ? 'Saved planning evidence checked: no active tasks or goals were found for this account.'
            : 'No readable active task or goal was available, so guidance used check-in context only.',
      );
    } else if (!hasMatchedStoredEvidence) {
      evidence.add(
        'Saved planning evidence checked: ${activeTasks.length} active task(s) and ${activeGoals.length} active goal(s), with no positive relevance match to this check-in.',
      );
    } else {
      evidence.add(
        'Saved planning evidence read at ${observedAt.toIso8601String()}: ${activeTasks.length} active task(s), ${activeGoals.length} active goal(s).',
      );
      final TaskEntity? task = focusTask;
      if (task != null) {
        final DateTime? relevantDate = task.dueDate ?? task.scheduledFor;
        final String timing = relevantDate == null
            ? 'no saved due or scheduled time'
            : '${task.dueDate != null ? 'due' : 'scheduled'} ${_dateLabel(relevantDate)}';
        evidence.add(
          'Focused saved task: "${SmartPlannerQueryController._safeEvidenceTitle(task.title)}"; priority ${task.priority}/5; energy ${task.energyRequired}/5; $timing.',
        );
      }
      final GoalEntity? goal = focusGoal;
      if (goal != null) {
        evidence.add(
          'Focused saved goal: "${SmartPlannerQueryController._safeEvidenceTitle(goal.title)}"; ${goal.targetDate == null ? 'no target date' : 'target ${_dateLabel(goal.targetDate!)}'}.',
        );
      }
    }
    evidence.addAll(operatingReceipt.verifiedEvidence());
    evidence.addAll(plannerMemory.verifiedEvidence());
    evidence.addAll(personContext.verifiedEvidence());
    return evidence;
  }

  List<String> clarificationEvidence(DateTime observedAt) {
    final List<String> evidence = <String>[
      if (!taskReadSucceeded || !goalReadSucceeded)
        'Saved planning evidence was only partially available for this check-in.'
      else if (hasStoredEvidence)
        'Saved planning evidence checked at ${observedAt.toIso8601String()}: ${activeTasks.length} active task(s), ${activeGoals.length} active goal(s); none was attached without positive relevance.'
      else
        'Saved planning evidence checked: no active tasks or goals were found for this account.',
      ...operatingReceipt.clarificationEvidence(),
      ...plannerMemory.verifiedEvidence(),
      ...personContext.verifiedEvidence(),
    ];
    return evidence;
  }
}

enum _PlannerOperatingReceiptStatus { unavailable, expired, unmatched, matched }

final class _PlannerOperatingReceiptEvidence {
  const _PlannerOperatingReceiptEvidence.unavailable()
    : status = _PlannerOperatingReceiptStatus.unavailable,
      receipt = null;

  const _PlannerOperatingReceiptEvidence._(this.status, this.receipt);

  factory _PlannerOperatingReceiptEvidence.resolve(
    OperatingDecisionReceipt? receipt, {
    required String searchText,
    required DateTime now,
  }) {
    if (receipt == null) {
      return const _PlannerOperatingReceiptEvidence.unavailable();
    }
    try {
      receipt.validate();
    } on Object {
      return const _PlannerOperatingReceiptEvidence.unavailable();
    }
    if (receipt.isExpiredAt(now)) {
      return _PlannerOperatingReceiptEvidence._(
        _PlannerOperatingReceiptStatus.expired,
        receipt,
      );
    }
    final Set<String> queryTerms = _plannerTerms(searchText);
    final Set<String> receiptTerms = _plannerTerms(
      <String>[
        receipt.recommendedAction,
        receipt.rationale,
        receipt.whyItMatters,
        ...receipt.evidence.map((OperatingEvidence item) => item.description),
      ].join(' '),
    );
    final bool matched = queryTerms.any(receiptTerms.contains);
    return _PlannerOperatingReceiptEvidence._(
      matched
          ? _PlannerOperatingReceiptStatus.matched
          : _PlannerOperatingReceiptStatus.unmatched,
      receipt,
    );
  }

  final _PlannerOperatingReceiptStatus status;
  final OperatingDecisionReceipt? receipt;

  OperatingDecisionReceipt? get focus =>
      status == _PlannerOperatingReceiptStatus.matched ? receipt : null;

  bool get wasAvailable =>
      status == _PlannerOperatingReceiptStatus.matched ||
      status == _PlannerOperatingReceiptStatus.unmatched;

  String get adaptationSummary => switch (status) {
    _PlannerOperatingReceiptStatus.matched =>
      'Used a recent saved planning recommendation only after a positive relevance match.',
    _PlannerOperatingReceiptStatus.unmatched =>
      'A recent saved planning recommendation was available but not used because it did not match this check-in.',
    _PlannerOperatingReceiptStatus.expired =>
      'The saved planning recommendation had expired and was not used.',
    _PlannerOperatingReceiptStatus.unavailable =>
      'No recent saved planning recommendation was available.',
  };

  Map<String, Object?> get requestContext => <String, Object?>{
    'operatingReceiptStatus': status.name,
    'operatingReceiptUsed': focus != null,
    'operatingReceiptId': focus?.decisionId,
  };

  List<String> verifiedEvidence() => switch (status) {
    _PlannerOperatingReceiptStatus.matched => <String>[
      'A saved planning recommendation matched this check-in: "${SmartPlannerQueryController._safeEvidenceTitle(receipt!.recommendedAction)}"; generated ${receipt!.generatedAt.toUtc().toIso8601String()}; expires ${receipt!.expiresAt.toUtc().toIso8601String()}.',
    ],
    _PlannerOperatingReceiptStatus.unmatched => const <String>[
      'A recent saved planning recommendation was checked but not attached because it had no positive relevance match.',
    ],
    _PlannerOperatingReceiptStatus.expired => const <String>[
      'The available saved planning recommendation had expired and was not used.',
    ],
    _PlannerOperatingReceiptStatus.unavailable => const <String>[
      'No recent saved planning recommendation was available for this check-in.',
    ],
  };

  List<String> clarificationEvidence() => switch (status) {
    _PlannerOperatingReceiptStatus.matched ||
    _PlannerOperatingReceiptStatus.unmatched => const <String>[
      'A recent saved planning recommendation was checked and was not attached while clarification is needed.',
    ],
    _PlannerOperatingReceiptStatus.expired => const <String>[
      'The available saved planning recommendation had expired and was not used.',
    ],
    _PlannerOperatingReceiptStatus.unavailable => const <String>[
      'No recent saved planning recommendation was available for this check-in.',
    ],
  };
}

final class _PlannerMemoryEvidence {
  const _PlannerMemoryEvidence.empty() : memories = const <MemoryEntity>[];

  const _PlannerMemoryEvidence._(this.memories);

  factory _PlannerMemoryEvidence.resolve(
    List<MemoryEntity> memories, {
    required DateTime now,
  }) {
    final List<MemoryEntity> authorized = memories
        .where(
          (MemoryEntity memory) =>
              memory.sourceSurface == MemorySurface.smartPlanner &&
              memory.purpose == MemoryPurpose.guidancePreference &&
              memory.consentStatus == MemoryConsentStatus.granted &&
              memory.sensitivity != MemorySensitivity.emotional &&
              memory.sensitivity != MemorySensitivity.crisis &&
              !memory.isArchived &&
              !memory.isExpiredAt(now),
        )
        .take(2)
        .toList(growable: false);
    return _PlannerMemoryEvidence._(
      List<MemoryEntity>.unmodifiable(authorized),
    );
  }

  final List<MemoryEntity> memories;

  String get adaptationSummary => memories.isEmpty
      ? 'No governed Smart Planner preference was recalled.'
      : 'Recalled ${memories.length} consented Smart Planner guidance preference(s) through the exact surface and purpose boundary.';

  Map<String, Object?> get requestContext => <String, Object?>{
    'plannerMemoryPurpose': MemoryPurpose.guidancePreference.name,
    'plannerMemorySignalsUsed': memories.length,
  };

  List<String> verifiedEvidence() {
    if (memories.isEmpty) {
      return const <String>[
        'No authorized governed Smart Planner preference was recalled.',
      ];
    }
    return memories
        .map(
          (MemoryEntity memory) =>
              'Governed Smart Planner preference recalled for ${memory.purpose.name}: "${SmartPlannerQueryController._condense(memory.text.replaceAll('"', "'"), maxLength: 120)}". It remained bounded to Smart Planner.',
        )
        .toList(growable: false);
  }
}

const int _maxPlannerPersonContextSignals = 3;

const Map<PersonContextBehaviorField, Object?> _plannerNoContextBaseline =
    <PersonContextBehaviorField, Object?>{
      PersonContextBehaviorField.supportingEvidence: 'none',
      PersonContextBehaviorField.planningScope: 'request-only',
      PersonContextBehaviorField.rankingPriority: 'saved-work-order',
      PersonContextBehaviorField.capacityLimit: 'current-check-in',
      PersonContextBehaviorField.responseWording: 'default',
      PersonContextBehaviorField.hardBoundary: 'none',
      PersonContextBehaviorField.scheduledCommitment: 'saved-work-only',
    };

enum _PlannerPersonContextStatus { unavailable, knownEmpty, available }

final class _PlannerPersonContextEvidence {
  const _PlannerPersonContextEvidence.unavailable({
    this.behaviorRevision = 'person-context-unavailable',
  }) : status = _PlannerPersonContextStatus.unavailable,
       signals = const <_PlannerPersonContextSignal>[],
       availableSignalCount = 0,
       appliedOutput = _plannerNoContextBaseline,
       trace = null;

  const _PlannerPersonContextEvidence._({
    required this.status,
    required this.signals,
    required this.availableSignalCount,
    required this.appliedOutput,
    required this.trace,
    required this.behaviorRevision,
  });

  factory _PlannerPersonContextEvidence.resolve(
    PersonContextView? view, {
    required DateTime now,
    required String accountScopeId,
    required String decisionText,
  }) {
    if (view == null ||
        view.accountScopeId != accountScopeId ||
        view.surface != PersonContextSurface.smartPlanner ||
        !view.purposes.containsAll(operationalPersonContextPurposes)) {
      return _PlannerPersonContextEvidence.unavailable(
        behaviorRevision: _behaviorRevision(
          accountScopeId: accountScopeId,
          status: _PlannerPersonContextStatus.unavailable,
          usedSignals: const <PersonContextSignal>[],
        ),
      );
    }
    final Map<String, PersonContextRelevanceBasis> relevance =
        <String, PersonContextRelevanceBasis>{};
    final Set<String> decisionTerms = _plannerTerms(decisionText);
    for (final PersonContextSignal signal in view.signals) {
      final PersonContextRelevanceRule rule =
          PersonContextBehaviorPolicy.ruleFor(signal.kind).relevanceRule;
      final PersonContextRelevanceBasis? basis = switch (rule) {
        PersonContextRelevanceRule.exactDecisionSubject
            when _plannerTerms(signal.value).any(decisionTerms.contains) =>
          PersonContextRelevanceBasis.exactTextMatch,
        PersonContextRelevanceRule.exactDecisionSubject => null,
        PersonContextRelevanceRule.activePlanningWindow =>
          PersonContextRelevanceBasis.typedActivePlanningWindow,
        PersonContextRelevanceRule.responsePresentation =>
          PersonContextRelevanceBasis.typedResponsePresentation,
        PersonContextRelevanceRule.explicitBoundary =>
          PersonContextRelevanceBasis.typedExplicitBoundary,
        PersonContextRelevanceRule.explicitCommitment =>
          PersonContextRelevanceBasis.typedExplicitCommitment,
        PersonContextRelevanceRule.confirmedOutcome =>
          PersonContextRelevanceBasis.typedConfirmedOutcome,
      };
      if (basis != null) relevance[signal.id] = basis;
    }
    final PersonContextBehaviorTrace evaluated =
        PersonContextBehaviorPolicy.evaluate(
          signals: view.signals,
          surface: PersonContextSurface.smartPlanner,
          purposes: view.purposes,
          relevance: relevance,
          now: now,
          noContextBaseline: _plannerNoContextBaseline,
          maxUsedSignals: _maxPlannerPersonContextSignals,
        );
    final Map<String, PersonContextSignal> signalById =
        <String, PersonContextSignal>{
          for (final PersonContextSignal signal in view.signals)
            signal.id: signal,
        };
    final PersonContextBehaviorApplication application =
        PersonContextBehaviorPolicy.apply(
          trace: evaluated,
          effects: evaluated.used
              .map(
                (PersonContextBehaviorDecision decision) =>
                    PersonContextBehaviorEffect(
                      signalId: decision.signalId,
                      field: decision.permittedField,
                      value: signalById[decision.signalId]!.value,
                    ),
              )
              .toList(growable: false),
        );
    final PersonContextBehaviorTrace trace = application.trace;
    final Set<String> usedSignalIds = trace.used
        .map((PersonContextBehaviorDecision decision) => decision.signalId)
        .toSet();
    final List<PersonContextSignal> available =
        view.signals
            .where(
              (PersonContextSignal signal) => usedSignalIds.contains(signal.id),
            )
            .toList(growable: true)
          ..sort(PersonContextBehaviorPolicy.compareSignals);
    final int eligibleSignalCount =
        trace.used.length +
        trace.rejected
            .where(
              (PersonContextBehaviorDecision decision) =>
                  decision.rejectionReason ==
                  PersonContextRejectionReason.consumerLimitExceeded,
            )
            .length;
    if (available.isEmpty) {
      return _PlannerPersonContextEvidence._(
        status: _PlannerPersonContextStatus.knownEmpty,
        signals: const <_PlannerPersonContextSignal>[],
        availableSignalCount: eligibleSignalCount,
        appliedOutput: application.output,
        trace: trace,
        behaviorRevision: _behaviorRevision(
          accountScopeId: accountScopeId,
          status: _PlannerPersonContextStatus.knownEmpty,
          usedSignals: const <PersonContextSignal>[],
        ),
      );
    }
    return _PlannerPersonContextEvidence._(
      status: _PlannerPersonContextStatus.available,
      signals: List<_PlannerPersonContextSignal>.unmodifiable(
        available
            .take(_maxPlannerPersonContextSignals)
            .map(_PlannerPersonContextSignal.fromSignal),
      ),
      availableSignalCount: eligibleSignalCount,
      appliedOutput: application.output,
      trace: trace,
      behaviorRevision: _behaviorRevision(
        accountScopeId: accountScopeId,
        status: _PlannerPersonContextStatus.available,
        usedSignals: available,
      ),
    );
  }

  final _PlannerPersonContextStatus status;
  final List<_PlannerPersonContextSignal> signals;
  final int availableSignalCount;
  final Map<PersonContextBehaviorField, Object?> appliedOutput;
  final PersonContextBehaviorTrace? trace;
  final String behaviorRevision;

  static String _behaviorRevision({
    required String accountScopeId,
    required _PlannerPersonContextStatus status,
    required List<PersonContextSignal> usedSignals,
  }) {
    return evidenceContentDigest(<String, Object?>{
      'contract': 'smart-planner-person-context-behavior-v1',
      'accountScopeId': accountScopeId,
      'status': status.name,
      'usedSignals': usedSignals
          .map(
            (PersonContextSignal signal) => <String, Object?>{
              'id': signal.id,
              'kind': signal.kind.name,
              'value': signal.value,
              'source': signal.source.name,
              'consentedAt': signal.consentedAt?.toUtc().toIso8601String(),
              'purpose': signal.purpose.name,
              'surfaceScopes':
                  signal.surfaceScopes
                      .map((PersonContextSurface surface) => surface.name)
                      .toList(growable: false)
                    ..sort(),
              'recordedAt': signal.recordedAt.toUtc().toIso8601String(),
              'freshUntil': signal.freshUntil.toUtc().toIso8601String(),
              'expiresAt': signal.expiresAt.toUtc().toIso8601String(),
            },
          )
          .toList(growable: false),
    });
  }

  _PlannerPersonContextSignal? get planningFocus {
    for (final _PlannerPersonContextSignal signal in signals) {
      if (signal.canGroundPlanning && _hasAppliedEffect(signal)) return signal;
    }
    return null;
  }

  _PlannerPersonContextSignal? get rankingFocus {
    for (final _PlannerPersonContextSignal signal in signals) {
      if (signal.kind == PersonContextKind.currentPriority &&
          _hasAppliedEffect(signal)) {
        return signal;
      }
    }
    return null;
  }

  bool _hasAppliedEffect(_PlannerPersonContextSignal signal) {
    final PersonContextBehaviorField permittedField =
        PersonContextBehaviorPolicy.ruleFor(signal.kind).permittedField;
    if (!appliedOutput.containsKey(permittedField)) return false;
    return trace?.appliedDeltas.any(
          (PersonContextBehaviorDelta delta) =>
              delta.signalId == signal.id &&
              delta.field == permittedField &&
              delta.changed,
        ) ??
        false;
  }

  String get adaptationSummary => switch (status) {
    _PlannerPersonContextStatus.unavailable =>
      'Person context was unavailable and was not used.',
    _PlannerPersonContextStatus.knownEmpty =>
      'Person context was checked and known-empty for Smart Planner.',
    _PlannerPersonContextStatus.available =>
      'Used ${signals.length} consented fresh person-context signal(s), bounded to $_maxPlannerPersonContextSignals; treated them as user-provided evidence, not inferred identity.',
  };

  List<String> get changedFieldNames {
    final List<String> fields =
        trace?.changedFields
            .map((PersonContextBehaviorField field) => field.name)
            .toList(growable: true) ??
        <String>[];
    fields.sort();
    return List<String>.unmodifiable(fields);
  }

  Map<String, Object?> get requestContext => <String, Object?>{
    'personContextStatus': switch (status) {
      _PlannerPersonContextStatus.unavailable => 'unavailable',
      _PlannerPersonContextStatus.knownEmpty => 'known_empty',
      _PlannerPersonContextStatus.available => 'available',
    },
    'personContextAvailableSignalCount': availableSignalCount,
    'personContextSignalsUsed': signals.length,
    'personContextSignalsRejected': trace?.rejected.length ?? 0,
    'personContextEvidenceLimit': _maxPlannerPersonContextSignals,
    'personContextBehaviorRevision': behaviorRevision,
    'personContextEvidenceKinds': signals
        .map((_PlannerPersonContextSignal signal) => signal.kind.name)
        .toList(growable: false),
    'personContextChangedFields': changedFieldNames,
    if (trace != null) 'personContextDecisionTrace': trace!.toJson(),
  };

  List<String> verifiedEvidence() => switch (status) {
    _PlannerPersonContextStatus.unavailable => const <String>[
      'Person context was unavailable for Smart Planner and was not used.',
    ],
    _PlannerPersonContextStatus.knownEmpty => const <String>[
      'Person context checked for Smart Planner: no consented fresh signals were available.',
    ],
    _PlannerPersonContextStatus.available => <String>[
      'Person context checked for Smart Planner: $availableSignalCount consented fresh signal(s) available; ${signals.length} used with a limit of $_maxPlannerPersonContextSignals.',
      ...signals.map((_PlannerPersonContextSignal signal) => signal.evidence),
    ],
  };
}

final class _PlannerPersonContextSignal {
  const _PlannerPersonContextSignal({
    required this.id,
    required this.kind,
    required this.value,
    required this.source,
    required this.purpose,
  });

  factory _PlannerPersonContextSignal.fromSignal(PersonContextSignal signal) {
    return _PlannerPersonContextSignal(
      id: signal.id,
      kind: signal.kind,
      value: SmartPlannerQueryController._condense(
        signal.value.replaceAll('"', "'"),
        maxLength: 120,
      ),
      source: signal.source,
      purpose: signal.purpose,
    );
  }

  final String id;
  final PersonContextKind kind;
  final String value;
  final PersonContextSource source;
  final PersonContextPurpose purpose;

  bool get canGroundPlanning =>
      switch (PersonContextBehaviorPolicy.ruleFor(kind).overrideBehavior) {
        PersonContextOverrideBehavior.hardBoundary ||
        PersonContextOverrideBehavior.scheduleConstraint ||
        PersonContextOverrideBehavior.reduceOrRescopeOnly ||
        PersonContextOverrideBehavior.tieBreakOnly ||
        PersonContextOverrideBehavior.scopeOnly => true,
        PersonContextOverrideBehavior.safetyGate ||
        PersonContextOverrideBehavior.evidenceOnly ||
        PersonContextOverrideBehavior.wordingOnly ||
        PersonContextOverrideBehavior.calibrationOnly => false,
      };

  String get label => switch (kind) {
    PersonContextKind.role => 'role',
    PersonContextKind.value => 'value',
    PersonContextKind.currentPriority => 'current priority',
    PersonContextKind.lifeArea => 'life area',
    PersonContextKind.presentCapacity => 'present capacity',
    PersonContextKind.preferredSupportStyle => 'preferred support style',
    PersonContextKind.boundary => 'boundary',
    PersonContextKind.importantRelationship => 'important relationship',
    PersonContextKind.commitment => 'commitment',
    PersonContextKind.outcomeHistory => 'confirmed outcome history',
  };

  String get sourceLabel => switch (source) {
    PersonContextSource.userAuthored => 'user-authored',
    PersonContextSource.confirmedOutcome => 'confirmed outcome',
  };

  String get subject => '$sourceLabel $label "$value"';

  String get mattersMost =>
      'Respecting the $label you explicitly provided: "$value".';

  String get evidence =>
      'Verified person-context evidence: $sourceLabel $label for ${purpose.name}, "$value". This is a consented saved statement, not an inferred trait or identity.';
}

const Set<String> _plannerStopWords = <String>{
  'about',
  'after',
  'again',
  'could',
  'current',
  'give',
  'have',
  'help',
  'make',
  'need',
  'plan',
  'planner',
  'planning',
  'practical',
  'should',
  'that',
  'this',
  'today',
  'want',
  'what',
  'with',
  'would',
};

Set<String> _plannerTerms(String input) => RegExp(r'[a-z0-9]+')
    .allMatches(input.toLowerCase())
    .map((RegExpMatch match) => match.group(0)!)
    .where(
      (String term) => term.length >= 3 && !_plannerStopWords.contains(term),
    )
    .toSet();

int _taskTextMatch(TaskEntity task, Set<String> terms) {
  if (terms.isEmpty) return 0;
  final Set<String> titleTerms = _plannerTerms(task.title);
  final Set<String> descriptionTerms = _plannerTerms(task.description ?? '');
  return terms.where(titleTerms.contains).length * 4 +
      terms.where(descriptionTerms.contains).length;
}

int _goalTextMatch(GoalEntity goal, Set<String> terms) {
  if (terms.isEmpty) return 0;
  final Set<String> titleTerms = _plannerTerms(goal.title);
  final Set<String> descriptionTerms = _plannerTerms(goal.description ?? '');
  return terms.where(titleTerms.contains).length * 4 +
      terms.where(descriptionTerms.contains).length;
}

int _compareTasks(
  TaskEntity left,
  TaskEntity right, {
  required Set<String> terms,
  required DateTime now,
}) {
  final int leftScore =
      _taskTextMatch(left, terms) * 1000 + _taskPriorityScore(left, now);
  final int rightScore =
      _taskTextMatch(right, terms) * 1000 + _taskPriorityScore(right, now);
  final int scoreOrder = rightScore.compareTo(leftScore);
  return scoreOrder != 0 ? scoreOrder : left.title.compareTo(right.title);
}

int _taskPriorityScore(TaskEntity task, DateTime now) {
  int score = task.priority.clamp(1, 5) * 20;
  final DateTime? relevant = task.dueDate ?? task.scheduledFor;
  if (relevant == null) return score;
  if (!relevant.isAfter(now)) return score + 300;
  if (!relevant.isAfter(now.add(const Duration(days: 1)))) return score + 220;
  if (!relevant.isAfter(now.add(const Duration(days: 7)))) return score + 100;
  return score + 20;
}

int _compareGoals(
  GoalEntity left,
  GoalEntity right, {
  required Set<String> terms,
  required DateTime now,
}) {
  final int leftScore =
      _goalTextMatch(left, terms) * 1000 + _goalUrgencyScore(left, now);
  final int rightScore =
      _goalTextMatch(right, terms) * 1000 + _goalUrgencyScore(right, now);
  final int scoreOrder = rightScore.compareTo(leftScore);
  return scoreOrder != 0 ? scoreOrder : left.title.compareTo(right.title);
}

int _goalUrgencyScore(GoalEntity goal, DateTime now) {
  final DateTime? target = goal.targetDate;
  if (target == null) return 0;
  if (!target.isAfter(now)) return 200;
  if (!target.isAfter(now.add(const Duration(days: 7)))) return 100;
  if (!target.isAfter(now.add(const Duration(days: 30)))) return 40;
  return 10;
}

String _dateLabel(DateTime value) =>
    value.toLocal().toIso8601String().split('T').first;

AssistantSafetyReceipt _requirePublishableSafety(
  AssistantSafetyOutcome outcome,
) {
  if (!outcome.mayPublish) {
    throw const AssistantSafetyRouteException(
      'assistant_response_withheld',
      'The response did not pass the assistant safety boundary.',
    );
  }
  return outcome.receipt;
}

enum _PlannerTopic {
  overwhelm,
  habit,
  recovery,
  wellbeing,
  goal,
  focus,
  health,
  general,
}

final class _EffortProfile {
  const _EffortProfile(
    this.minimumMinutes,
    this.bestFitMinutes,
    this.stretchMinutes,
  );

  final int minimumMinutes;
  final int bestFitMinutes;
  final int stretchMinutes;
}

final class _PlannerStrategy {
  const _PlannerStrategy({
    required this.minimumTitle,
    required this.bestFitTitle,
    required this.stretchTitle,
    required this.mattersMost,
    required this.minimumAction,
    required this.bestFitAction,
    required this.stretchAction,
    required this.question,
  });

  final String minimumTitle;
  final String bestFitTitle;
  final String stretchTitle;
  final String mattersMost;
  final String Function(String subject) minimumAction;
  final String Function(String subject) bestFitAction;
  final String Function(String subject) stretchAction;
  final String question;
}

PlannerV2Response _compatibilityPlannerResponse({
  required String prompt,
  required String message,
  required List<String> evidence,
  required AIProcessingMode processingMode,
}) {
  final String safeMessage = message.trim().isEmpty
      ? 'Choose one concrete next action.'
      : message.trim();
  return PlannerV2Response(
    whatIHeard: prompt.trim().isEmpty ? 'You want planning guidance.' : prompt,
    mattersMost: 'A clear next action.',
    verifiedEvidence: evidence.isEmpty
        ? const <String>['Compatibility response; no stored evidence used.']
        : evidence,
    options: <PlannerOption>[
      PlannerOption(
        kind: PlannerOptionKind.minimum,
        title: 'Small start',
        description: safeMessage,
        estimatedMinutes: 5,
        tradeoff: 'Lowest effort.',
      ),
      PlannerOption(
        kind: PlannerOptionKind.bestFit,
        title: 'Practical step',
        description: safeMessage,
        estimatedMinutes: 20,
        tradeoff: 'Balanced effort.',
      ),
      PlannerOption(
        kind: PlannerOptionKind.stretch,
        title: 'Deeper pass',
        description: safeMessage,
        estimatedMinutes: 40,
        tradeoff: 'Higher effort.',
      ),
    ],
    recommendedKind: PlannerOptionKind.bestFit,
    recommendationReason: 'Compatibility response supplied by the caller.',
    nextStep: safeMessage,
    adaptationReceipt: PlannerAdaptationReceipt(
      userSetEnergy: null,
      userSelectedEmotion: null,
      adjustments: const <String>[
        'Compatibility mode did not use energy or infer emotional state.',
      ],
    ),
    origin: processingMode == AIProcessingMode.external
        ? PlannerResponseOrigin.externalModel
        : PlannerResponseOrigin.deterministic,
  );
}
