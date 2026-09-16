part of 'smart_planner_query_controller.dart';

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
      if (basis != null) {
        relevance[signal.id] = basis;
      }
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
      if (signal.canGroundPlanning && _hasAppliedEffect(signal)) {
        return signal;
      }
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

  /// A present-capacity signal can reduce or rescope a plan only when its
  /// applied value contains an explicit positive minute limit.
  int? get capacityLimitMinutes {
    for (final _PlannerPersonContextSignal signal in signals) {
      if (signal.kind != PersonContextKind.presentCapacity ||
          !_hasAppliedEffect(signal)) {
        continue;
      }
      final Object? value =
          appliedOutput[PersonContextBehaviorField.capacityLimit];
      final RegExpMatch? match = RegExp(
        r'\b(\d{1,3})\b',
      ).firstMatch(value is String ? value : '');
      final int? minutes = value is int
          ? value
          : int.tryParse(match?.group(1) ?? '');
      if (minutes != null && minutes > 0) {
        return minutes;
      }
    }
    return null;
  }

  bool _hasAppliedEffect(_PlannerPersonContextSignal signal) {
    final PersonContextBehaviorField permittedField =
        PersonContextBehaviorPolicy.ruleFor(signal.kind).permittedField;
    if (!appliedOutput.containsKey(permittedField)) {
      return false;
    }
    return trace?.appliedDeltas.any(
          (PersonContextBehaviorDelta delta) =>
              delta.signalId == signal.id &&
              delta.field == permittedField &&
              delta.changed,
        ) ??
        false;
  }

  String get adaptationSummary => adaptationSummaryFor();

  String adaptationSummaryFor({String languageCode = 'en'}) => switch (status) {
    _PlannerPersonContextStatus.unavailable => _plannerEvidenceText(
      languageCode,
      'Person context was unavailable and was not used.',
      'El Contexto Personal no estaba disponible y no se usó.',
    ),
    _PlannerPersonContextStatus.knownEmpty => _plannerEvidenceText(
      languageCode,
      'Person context was checked and known-empty for Smart Planner.',
      'Se comprobó que no había Contexto Personal disponible para el Planificador Inteligente.',
    ),
    _PlannerPersonContextStatus.available => _plannerEvidenceText(
      languageCode,
      'Used ${signals.length} consented fresh person-context signal(s), bounded to $_maxPlannerPersonContextSignals; treated them as user-provided evidence, not inferred identity.',
      'Se usaron ${signals.length} datos vigentes y autorizados del Contexto Personal, con un máximo de $_maxPlannerPersonContextSignals; se trataron como información aportada por ti, sin deducir tu identidad.',
    ),
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

  List<String> verifiedEvidence({
    String languageCode = 'en',
  }) => switch (status) {
    _PlannerPersonContextStatus.unavailable => <String>[
      _plannerEvidenceText(
        languageCode,
        'Person context was unavailable for Smart Planner and was not used.',
        'El Contexto Personal no estaba disponible para el Planificador Inteligente y no se usó.',
      ),
    ],
    _PlannerPersonContextStatus.knownEmpty => <String>[
      _plannerEvidenceText(
        languageCode,
        'Person context checked for Smart Planner: no consented fresh signals were available.',
        'Se comprobó el Contexto Personal para el Planificador Inteligente: no había datos vigentes con consentimiento.',
      ),
    ],
    _PlannerPersonContextStatus.available => <String>[
      _plannerEvidenceText(
        languageCode,
        'Person context checked for Smart Planner: $availableSignalCount consented fresh signal(s) available; ${signals.length} used with a limit of $_maxPlannerPersonContextSignals.',
        'Se comprobó el Contexto Personal para el Planificador Inteligente: $availableSignalCount datos vigentes con consentimiento disponibles; se usaron ${signals.length}, con un máximo de $_maxPlannerPersonContextSignals.',
      ),
      ...signals.map(
        (_PlannerPersonContextSignal signal) =>
            signal.evidenceFor(languageCode: languageCode),
      ),
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
        PersonContextOverrideBehavior.scopeOnly => true,
        PersonContextOverrideBehavior.safetyGate ||
        PersonContextOverrideBehavior.evidenceOnly ||
        PersonContextOverrideBehavior.wordingOnly ||
        PersonContextOverrideBehavior.calibrationOnly ||
        PersonContextOverrideBehavior.reduceOrRescopeOnly ||
        PersonContextOverrideBehavior.tieBreakOnly => false,
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

  String subjectFor({String languageCode = 'en'}) => _plannerEvidenceText(
    languageCode,
    subject,
    '${_plannerEvidenceLabel(kind.name)} (${_plannerEvidenceLabel(source.name)}) "$value"',
  );

  String get mattersMost =>
      'Respecting the $label you explicitly provided: "$value".';

  String mattersMostFor({String languageCode = 'en'}) => _plannerEvidenceText(
    languageCode,
    mattersMost,
    'Respetar lo que indicaste explícitamente sobre ${_plannerEvidenceLabel(kind.name)}: "$value".',
  );

  String get evidence =>
      'Verified person-context evidence: $sourceLabel $label for ${purpose.name}, "$value". This is a consented saved statement, not an inferred trait or identity.';

  String evidenceFor({String languageCode = 'en'}) => _plannerEvidenceText(
    languageCode,
    evidence,
    'Información verificada del Contexto Personal: ${_plannerEvidenceLabel(source.name)}, ${_plannerEvidenceLabel(kind.name)} para ${_plannerEvidenceLabel(purpose.name)}, "$value". Es una declaración guardada con consentimiento, no un rasgo o una identidad deducidos.',
  );
}
