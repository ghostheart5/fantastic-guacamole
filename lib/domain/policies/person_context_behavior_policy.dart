// CHRONOSPARK-CLASS: SHIPPING | Feature: Governed person-context behavior
import 'package:fantastic_guacamole/domain/entities/assistant_evidence_plane.dart';
import 'package:fantastic_guacamole/domain/entities/person_context.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';

enum PersonContextBehaviorField {
  supportingEvidence,
  planningScope,
  rankingPriority,
  capacityLimit,
  responseWording,
  hardBoundary,
  scheduledCommitment,
  outcomeCalibration,
}

enum PersonContextEffectSize {
  none,
  evidenceOnly,
  presentationOnly,
  tieBreak,
  boundedAdjustment,
  constraint,
}

/// Ordered authorities that can resolve a context conflict.
///
/// Safety is an external decision authority, not a [PersonContextKind]. It is
/// represented here so every consumer can use the binder-required ordering.
enum PersonContextConflictAuthority {
  boundary,
  safety,
  scheduledCommitment,
  freshCapacity,
  currentPriority,
  preferenceOrWording,
  evidenceOnly,
}

enum PersonContextOverrideBehavior {
  hardBoundary,
  safetyGate,
  scheduleConstraint,
  reduceOrRescopeOnly,
  tieBreakOnly,
  wordingOnly,
  scopeOnly,
  evidenceOnly,
  calibrationOnly,
}

enum PersonContextRelevanceRule {
  exactDecisionSubject,
  activePlanningWindow,
  responsePresentation,
  explicitBoundary,
  explicitCommitment,
  confirmedOutcome,
}

enum PersonContextProhibitedInference {
  stableIdentityOrTrait,
  diagnosisOrHealthState,
  intentBeyondExactText,
  relationshipQuality,
  futureOutcome,
}

enum PersonContextDecisionStatus { used, rejected }

enum PersonContextRejectionReason {
  irrelevant,
  userOverride,
  invalidRelevanceBasis,
  purposeNotAllowed,
  surfaceNotAllowed,
  surfaceNotConsented,
  unknown,
  empty,
  sourceNotAllowed,
  consentMissing,
  consentWithdrawn,
  consentNotEffective,
  futureDated,
  expired,
  stale,
  freshnessWindowExceeded,
  unavailable,
  consumerLimitExceeded,
  safetyPreempted,
  supersededByHigherAuthority,
}

/// A positive, structured reason a particular signal is relevant to the
/// decision being evaluated. Signal kind alone is never sufficient.
enum PersonContextRelevanceBasis {
  exactTextMatch,
  typedActivePlanningWindow,
  typedResponsePresentation,
  typedExplicitBoundary,
  typedExplicitCommitment,
  typedConfirmedOutcome,
  typedReviewEvidence,
}

final class PersonContextBehaviorRule {
  const PersonContextBehaviorRule._({
    required this.kind,
    required this.allowedSurfaces,
    required this.purpose,
    required this.relevanceRule,
    required this.maxFreshness,
    required this.permittedField,
    required this.effectSize,
    required this.conflictAuthority,
    required this.prohibitedInferences,
    required this.overrideBehavior,
  });

  final PersonContextKind kind;
  final Set<PersonContextSurface> allowedSurfaces;
  final PersonContextPurpose purpose;
  final PersonContextRelevanceRule relevanceRule;
  final Duration maxFreshness;
  final PersonContextBehaviorField permittedField;
  final PersonContextEffectSize effectSize;
  final PersonContextConflictAuthority conflictAuthority;
  final Set<PersonContextProhibitedInference> prohibitedInferences;
  final PersonContextOverrideBehavior overrideBehavior;
}

final class PersonContextBehaviorDecision {
  const PersonContextBehaviorDecision._({
    required this.signalId,
    required this.kind,
    required this.status,
    required this.permittedField,
    required this.effectSize,
    required this.conflictAuthority,
    required this.overrideBehavior,
    required this.relevanceRule,
    this.relevanceBasis,
    this.rejectionReason,
  });

  final String signalId;
  final PersonContextKind kind;
  final PersonContextDecisionStatus status;
  final PersonContextBehaviorField permittedField;
  final PersonContextEffectSize effectSize;
  final PersonContextConflictAuthority conflictAuthority;
  final PersonContextOverrideBehavior overrideBehavior;
  final PersonContextRelevanceRule relevanceRule;
  final PersonContextRelevanceBasis? relevanceBasis;
  final PersonContextRejectionReason? rejectionReason;

  Map<String, Object?> toTraceJson() => <String, Object?>{
    'signalId': signalId,
    'kind': kind.name,
    'status': status.name,
    'permittedField': permittedField.name,
    'effectSize': effectSize.name,
    'conflictAuthority': conflictAuthority.name,
    'overrideBehavior': overrideBehavior.name,
    'relevanceRule': relevanceRule.name,
    'reason': status == PersonContextDecisionStatus.used
        ? relevanceBasis!.name
        : rejectionReason!.name,
  };
}

final class PersonContextBehaviorEffect {
  const PersonContextBehaviorEffect({
    required this.signalId,
    required this.field,
    required this.value,
  });

  final String signalId;
  final PersonContextBehaviorField field;
  final Object? value;
}

/// Privacy-safe evidence of one actual output field change.
final class PersonContextBehaviorDelta {
  const PersonContextBehaviorDelta({
    required this.signalId,
    required this.field,
    required this.effectSize,
    required this.conflictAuthority,
    required this.beforeDigest,
    required this.afterDigest,
    required this.changed,
  });

  final String signalId;
  final PersonContextBehaviorField field;
  final PersonContextEffectSize effectSize;
  final PersonContextConflictAuthority conflictAuthority;
  final String beforeDigest;
  final String afterDigest;
  final bool changed;

  Map<String, Object?> toTraceJson() => <String, Object?>{
    'signalId': signalId,
    'field': field.name,
    'effectSize': effectSize.name,
    'conflictAuthority': conflictAuthority.name,
    'beforeDigest': beforeDigest,
    'afterDigest': afterDigest,
    'changed': changed,
  };
}

final class PersonContextBehaviorApplication {
  PersonContextBehaviorApplication({
    required Map<PersonContextBehaviorField, Object?> output,
    required this.trace,
  }) : output = Map<PersonContextBehaviorField, Object?>.unmodifiable(output);

  final Map<PersonContextBehaviorField, Object?> output;
  final PersonContextBehaviorTrace trace;
}

enum GovernedDecisionContextStatus { unavailable, knownEmpty, applied }

/// The only Person Context input accepted by the canonical decision engine.
///
/// It contains typed task ids and bounded numbers, never unconstrained score
/// multipliers or inferred traits. Construction is policy-owned so ranking
/// cannot reinterpret raw context independently.
final class GovernedDecisionContext {
  GovernedDecisionContext._({
    required this.accountScopeId,
    required this.surface,
    required this.status,
    required Set<String> appliedSignalIds,
    required Set<String> priorityTaskIds,
    required Set<String> excludedTaskIds,
    required Set<String> protectedCommitmentTaskIds,
    required this.capacityCapMinutes,
    required List<String> explanations,
    required this.trace,
  }) : appliedSignalIds = Set<String>.unmodifiable(appliedSignalIds),
       priorityTaskIds = Set<String>.unmodifiable(priorityTaskIds),
       excludedTaskIds = Set<String>.unmodifiable(excludedTaskIds),
       protectedCommitmentTaskIds = Set<String>.unmodifiable(
         protectedCommitmentTaskIds,
       ),
       explanations = List<String>.unmodifiable(explanations),
       revision = evidenceContentDigest(<String, Object?>{
         'contract': 'governed-decision-context-v1',
         'accountScopeId': accountScopeId,
         'surface': surface.name,
         'status': status.name,
         'appliedSignalIds': appliedSignalIds.toList()..sort(),
         'priorityTaskIds': priorityTaskIds.toList()..sort(),
         'excludedTaskIds': excludedTaskIds.toList()..sort(),
         'protectedCommitmentTaskIds': protectedCommitmentTaskIds.toList()
           ..sort(),
         'capacityCapMinutes': capacityCapMinutes,
       });

  factory GovernedDecisionContext.unavailable(
    String accountScopeId, {
    PersonContextSurface surface = PersonContextSurface.nexus,
  }) => GovernedDecisionContext._(
    accountScopeId: accountScopeId,
    surface: surface,
    status: GovernedDecisionContextStatus.unavailable,
    appliedSignalIds: const <String>{},
    priorityTaskIds: const <String>{},
    excludedTaskIds: const <String>{},
    protectedCommitmentTaskIds: const <String>{},
    capacityCapMinutes: null,
    explanations: const <String>[],
    trace: null,
  );

  factory GovernedDecisionContext.resolve({
    required PersonContextView? view,
    required String accountScopeId,
    required List<TaskEntity> tasks,
    required DateTime now,
    Set<String> ignoredSignalIds = const <String>{},
    PersonContextSurface surface = PersonContextSurface.nexus,
  }) {
    if (view == null ||
        view.accountScopeId != accountScopeId ||
        view.surface != surface ||
        !view.purposes.containsAll(operationalPersonContextPurposes)) {
      return GovernedDecisionContext.unavailable(
        accountScopeId,
        surface: surface,
      );
    }

    final Map<String, TaskEntity> taskById = <String, TaskEntity>{
      for (final TaskEntity task in tasks) task.id: task,
    };
    final Map<String, Set<String>> matchedTaskIds = <String, Set<String>>{};
    final Map<String, PersonContextRelevanceBasis> relevance =
        <String, PersonContextRelevanceBasis>{};
    final Map<String, int> capacityCaps = <String, int>{};

    for (final PersonContextSignal signal in view.signals) {
      switch (signal.kind) {
        case PersonContextKind.currentPriority:
          final Set<String> matches = _bestTaskMatches(signal.value, tasks);
          if (matches.isNotEmpty) {
            matchedTaskIds[signal.id] = matches;
            relevance[signal.id] = PersonContextRelevanceBasis.exactTextMatch;
          }
        case PersonContextKind.boundary:
          final Set<String> matches = _bestTaskMatches(signal.value, tasks);
          if (_hasExplicitBoundaryLanguage(signal.value) &&
              matches.isNotEmpty) {
            matchedTaskIds[signal.id] = matches;
            relevance[signal.id] =
                PersonContextRelevanceBasis.typedExplicitBoundary;
          }
        case PersonContextKind.presentCapacity:
          final int? cap = _parseCapacityCap(signal.value);
          if (cap != null) {
            capacityCaps[signal.id] = cap;
            relevance[signal.id] =
                PersonContextRelevanceBasis.typedActivePlanningWindow;
          }
        case PersonContextKind.commitment:
          final Set<String> matches = _bestTaskMatches(signal.value, tasks);
          if (_hasExplicitCommitmentLanguage(signal.value) &&
              matches.isNotEmpty) {
            matchedTaskIds[signal.id] = matches;
            relevance[signal.id] =
                PersonContextRelevanceBasis.typedExplicitCommitment;
          }
        case PersonContextKind.role ||
            PersonContextKind.value ||
            PersonContextKind.lifeArea ||
            PersonContextKind.preferredSupportStyle ||
            PersonContextKind.importantRelationship ||
            PersonContextKind.outcomeHistory:
          break;
      }
    }

    final Map<PersonContextBehaviorField, Object?> baseline =
        <PersonContextBehaviorField, Object?>{
          PersonContextBehaviorField.rankingPriority: const <String>[],
          PersonContextBehaviorField.hardBoundary: const <String>[],
          PersonContextBehaviorField.capacityLimit: null,
          PersonContextBehaviorField.scheduledCommitment: const <String>[],
        };
    PersonContextBehaviorTrace evaluated = PersonContextBehaviorPolicy.evaluate(
      signals: view.signals,
      surface: surface,
      purposes: view.purposes,
      relevance: relevance,
      now: now,
      noContextBaseline: baseline,
      ignoredSignalIds: ignoredSignalIds,
    );

    // A hard boundary is authoritative over lower-order task instructions. A
    // commitment or current-priority signal that names the same task must not
    // survive into the governed context (or its explanation) after that task
    // has been excluded.
    final Set<String> boundaryTaskIds = evaluated.used
        .where(
          (PersonContextBehaviorDecision decision) =>
              decision.kind == PersonContextKind.boundary,
        )
        .expand(
          (PersonContextBehaviorDecision decision) =>
              matchedTaskIds[decision.signalId] ?? const <String>{},
        )
        .toSet();
    if (boundaryTaskIds.isNotEmpty) {
      final Set<String> supersededSignalIds = <String>{};
      for (final PersonContextSignal signal in view.signals) {
        if (signal.kind != PersonContextKind.currentPriority &&
            signal.kind != PersonContextKind.commitment) {
          continue;
        }
        final Set<String>? originalMatches = matchedTaskIds[signal.id];
        if (originalMatches == null || originalMatches.isEmpty) continue;
        final Set<String> remainingMatches = <String>{...originalMatches}
          ..removeAll(boundaryTaskIds);
        if (remainingMatches.isEmpty) {
          supersededSignalIds.add(signal.id);
        } else {
          matchedTaskIds[signal.id] = remainingMatches;
        }
      }
      if (supersededSignalIds.isNotEmpty) {
        evaluated = PersonContextBehaviorPolicy.evaluate(
          signals: view.signals,
          surface: surface,
          purposes: view.purposes,
          relevance: relevance,
          now: now,
          noContextBaseline: baseline,
          ignoredSignalIds: ignoredSignalIds,
          supersededSignalIds: supersededSignalIds,
        );
      }
    }
    final List<PersonContextBehaviorEffect> effects =
        <PersonContextBehaviorEffect>[];
    final Set<String> priorityTaskIds = <String>{};
    final Set<String> excludedTaskIds = <String>{};
    final Set<String> protectedCommitmentTaskIds = <String>{};
    int? capacityCapMinutes;
    final List<String> explanations = <String>[];
    for (final PersonContextBehaviorDecision decision in evaluated.used) {
      final Set<String> matches =
          matchedTaskIds[decision.signalId] ?? const <String>{};
      switch (decision.kind) {
        case PersonContextKind.currentPriority:
          priorityTaskIds.addAll(matches);
          effects.add(
            PersonContextBehaviorEffect(
              signalId: decision.signalId,
              field: decision.permittedField,
              value: matches.toList()..sort(),
            ),
          );
          explanations.add(
            'Current priority matched ${_taskLabels(matches, taskById)} and may only break a close ranking tie.',
          );
        case PersonContextKind.boundary:
          excludedTaskIds.addAll(matches);
          effects.add(
            PersonContextBehaviorEffect(
              signalId: decision.signalId,
              field: decision.permittedField,
              value: matches.toList()..sort(),
            ),
          );
          explanations.add(
            'Explicit boundary excluded ${_taskLabels(matches, taskById)} from this decision.',
          );
        case PersonContextKind.presentCapacity:
          capacityCapMinutes = capacityCaps[decision.signalId];
          effects.add(
            PersonContextBehaviorEffect(
              signalId: decision.signalId,
              field: decision.permittedField,
              value: capacityCapMinutes,
            ),
          );
          explanations.add(
            'Fresh capacity limited this decision to $capacityCapMinutes minutes.',
          );
        case PersonContextKind.commitment:
          protectedCommitmentTaskIds.addAll(matches);
          effects.add(
            PersonContextBehaviorEffect(
              signalId: decision.signalId,
              field: decision.permittedField,
              value: matches.toList()..sort(),
            ),
          );
          explanations.add(
            'Scheduled commitment protected ${_taskLabels(matches, taskById)} during conflict checks.',
          );
        case PersonContextKind.role ||
            PersonContextKind.value ||
            PersonContextKind.lifeArea ||
            PersonContextKind.preferredSupportStyle ||
            PersonContextKind.importantRelationship ||
            PersonContextKind.outcomeHistory:
          break;
      }
    }
    final PersonContextBehaviorApplication application =
        PersonContextBehaviorPolicy.apply(trace: evaluated, effects: effects);
    return GovernedDecisionContext._(
      accountScopeId: accountScopeId,
      surface: surface,
      status: effects.isEmpty
          ? GovernedDecisionContextStatus.knownEmpty
          : GovernedDecisionContextStatus.applied,
      appliedSignalIds: effects
          .map((PersonContextBehaviorEffect effect) => effect.signalId)
          .toSet(),
      priorityTaskIds: priorityTaskIds,
      excludedTaskIds: excludedTaskIds,
      protectedCommitmentTaskIds: protectedCommitmentTaskIds,
      capacityCapMinutes: capacityCapMinutes,
      explanations: explanations,
      trace: application.trace,
    );
  }

  final String accountScopeId;
  final PersonContextSurface surface;
  final GovernedDecisionContextStatus status;
  final Set<String> appliedSignalIds;
  final Set<String> priorityTaskIds;
  final Set<String> excludedTaskIds;
  final Set<String> protectedCommitmentTaskIds;
  final int? capacityCapMinutes;
  final List<String> explanations;
  final PersonContextBehaviorTrace? trace;
  final String revision;

  bool get hasAppliedBehavior =>
      status == GovernedDecisionContextStatus.applied;
}

const Set<String> _decisionContextStopWords = <String>{
  'after',
  'avoid',
  'before',
  'current',
  'first',
  'keep',
  'minutes',
  'never',
  'priority',
  'protect',
  'schedule',
  'scheduled',
  'should',
  'task',
  'this',
  'today',
  'tonight',
  'with',
};

Set<String> _decisionContextTerms(String input) => RegExp(r'[a-z0-9]+')
    .allMatches(input.toLowerCase())
    .map((RegExpMatch match) => match.group(0)!)
    .where(
      (String term) =>
          term.length >= 3 && !_decisionContextStopWords.contains(term),
    )
    .toSet();

Set<String> _bestTaskMatches(String signalValue, List<TaskEntity> tasks) {
  final Set<String> signalTerms = _decisionContextTerms(signalValue);
  if (signalTerms.isEmpty) return const <String>{};
  int bestScore = 0;
  final Set<String> matches = <String>{};
  for (final TaskEntity task in tasks) {
    final Set<String> titleTerms = _decisionContextTerms(task.title);
    final Set<String> descriptionTerms = _decisionContextTerms(
      task.description ?? '',
    );
    final int score =
        signalTerms.where(titleTerms.contains).length * 4 +
        signalTerms.where(descriptionTerms.contains).length;
    if (score <= 0 || score < bestScore) continue;
    if (score > bestScore) {
      bestScore = score;
      matches.clear();
    }
    matches.add(task.id);
  }
  return matches;
}

bool _hasExplicitBoundaryLanguage(String value) => RegExp(
  r"\b(do not|don't|never|avoid|exclude|must not)\b",
  caseSensitive: false,
).hasMatch(value);

bool _hasExplicitCommitmentLanguage(String value) => RegExp(
  r'\b(commitment|appointment|meeting|scheduled|keep|must|deadline)\b',
  caseSensitive: false,
).hasMatch(value);

int? _parseCapacityCap(String value) {
  final RegExpMatch? explicit = RegExp(
    r'\b(\d{1,3})\s*(?:minute|minutes|min)\b',
    caseSensitive: false,
  ).firstMatch(value);
  if (explicit != null) {
    return int.parse(explicit.group(1)!).clamp(5, 240);
  }
  final String normalized = value.toLowerCase();
  if (RegExp(r'\b(low|limited|small|short|tired)\b').hasMatch(normalized)) {
    return 25;
  }
  return null;
}

String _taskLabels(Set<String> ids, Map<String, TaskEntity> taskById) {
  final List<String> labels =
      ids.map((String id) => taskById[id]?.title ?? id).toList(growable: true)
        ..sort();
  return labels.map((String value) => '"$value"').join(', ');
}

/// Privacy-safe, deterministic evidence of how person context was evaluated.
///
/// Signal values are deliberately absent. Callers provide a structured,
/// privacy-safe baseline and retain responsibility for applying an approved
/// signal only to its [PersonContextBehaviorDecision.permittedField].
final class PersonContextBehaviorTrace {
  PersonContextBehaviorTrace({
    required this.surface,
    required Set<PersonContextPurpose> purposes,
    required this.observedAt,
    required Map<PersonContextBehaviorField, Object?> noContextBaseline,
    required List<PersonContextBehaviorDecision> decisions,
    List<PersonContextBehaviorDelta> appliedDeltas =
        const <PersonContextBehaviorDelta>[],
  }) : purposes = Set<PersonContextPurpose>.unmodifiable(purposes),
       noContextBaseline =
           Map<PersonContextBehaviorField, Object?>.unmodifiable(
             noContextBaseline,
           ),
       decisions = List<PersonContextBehaviorDecision>.unmodifiable(decisions),
       appliedDeltas = List<PersonContextBehaviorDelta>.unmodifiable(
         appliedDeltas,
       );

  final PersonContextSurface surface;
  final Set<PersonContextPurpose> purposes;
  final DateTime observedAt;
  final Map<PersonContextBehaviorField, Object?> noContextBaseline;
  final List<PersonContextBehaviorDecision> decisions;
  final List<PersonContextBehaviorDelta> appliedDeltas;

  PersonContextBehaviorTrace withAppliedDeltas(
    List<PersonContextBehaviorDelta> deltas,
  ) => PersonContextBehaviorTrace(
    surface: surface,
    purposes: purposes,
    observedAt: observedAt,
    noContextBaseline: noContextBaseline,
    decisions: decisions,
    appliedDeltas: deltas,
  );

  List<PersonContextBehaviorDecision> get used =>
      List<PersonContextBehaviorDecision>.unmodifiable(
        decisions.where(
          (PersonContextBehaviorDecision decision) =>
              decision.status == PersonContextDecisionStatus.used,
        ),
      );

  List<PersonContextBehaviorDecision> get rejected =>
      List<PersonContextBehaviorDecision>.unmodifiable(
        decisions.where(
          (PersonContextBehaviorDecision decision) =>
              decision.status == PersonContextDecisionStatus.rejected,
        ),
      );

  Set<PersonContextBehaviorField> get changedFields =>
      Set<PersonContextBehaviorField>.unmodifiable(
        appliedDeltas.isEmpty
            ? used.map(
                (PersonContextBehaviorDecision decision) =>
                    decision.permittedField,
              )
            : appliedDeltas
                  .where((PersonContextBehaviorDelta delta) => delta.changed)
                  .map((PersonContextBehaviorDelta delta) => delta.field),
      );

  Map<String, Object?> toJson() {
    final List<PersonContextPurpose> orderedPurposes = purposes.toList()
      ..sort(
        (PersonContextPurpose left, PersonContextPurpose right) =>
            left.index.compareTo(right.index),
      );
    final List<MapEntry<PersonContextBehaviorField, Object?>> baselineEntries =
        noContextBaseline.entries.toList()..sort(
          (
            MapEntry<PersonContextBehaviorField, Object?> left,
            MapEntry<PersonContextBehaviorField, Object?> right,
          ) => left.key.index.compareTo(right.key.index),
        );
    return <String, Object?>{
      'surface': surface.name,
      'purposes': orderedPurposes
          .map((PersonContextPurpose purpose) => purpose.name)
          .toList(growable: false),
      'observedAt': observedAt.toUtc().toIso8601String(),
      'noContextBaseline': <String, Object?>{
        for (final MapEntry<PersonContextBehaviorField, Object?> entry
            in baselineEntries)
          entry.key.name: entry.value,
      },
      'used': used
          .map(
            (PersonContextBehaviorDecision decision) => decision.toTraceJson(),
          )
          .toList(growable: false),
      'rejected': rejected
          .map(
            (PersonContextBehaviorDecision decision) => decision.toTraceJson(),
          )
          .toList(growable: false),
      'appliedDelta': appliedDeltas
          .map((PersonContextBehaviorDelta delta) => delta.toTraceJson())
          .toList(growable: false),
    };
  }
}

const Set<PersonContextSurface> _operationalSurfaces = <PersonContextSurface>{
  PersonContextSurface.smartPlanner,
  PersonContextSurface.siConsole,
  PersonContextSurface.nexus,
  PersonContextSurface.trajectory,
  PersonContextSurface.creator,
};

const Set<PersonContextSurface> _outcomeSurfaces = <PersonContextSurface>{
  PersonContextSurface.nexus,
  PersonContextSurface.trajectory,
};

const Set<PersonContextProhibitedInference> _neverInferFromContext =
    <PersonContextProhibitedInference>{
      PersonContextProhibitedInference.stableIdentityOrTrait,
      PersonContextProhibitedInference.diagnosisOrHealthState,
      PersonContextProhibitedInference.intentBeyondExactText,
      PersonContextProhibitedInference.relationshipQuality,
      PersonContextProhibitedInference.futureOutcome,
    };

/// The single domain authority for legal Person Context effects.
abstract final class PersonContextBehaviorPolicy {
  /// Literal binder order. Evidence-only context never wins a conflict and is
  /// ranked after these authorities by [conflictRank].
  static const List<PersonContextConflictAuthority> conflictOrder =
      <PersonContextConflictAuthority>[
        PersonContextConflictAuthority.boundary,
        PersonContextConflictAuthority.safety,
        PersonContextConflictAuthority.scheduledCommitment,
        PersonContextConflictAuthority.freshCapacity,
        PersonContextConflictAuthority.currentPriority,
        PersonContextConflictAuthority.preferenceOrWording,
      ];

  static const Map<PersonContextKind, PersonContextBehaviorRule> matrix =
      <PersonContextKind, PersonContextBehaviorRule>{
        PersonContextKind.role: PersonContextBehaviorRule._(
          kind: PersonContextKind.role,
          allowedSurfaces: _operationalSurfaces,
          purpose: PersonContextPurpose.decisionSupport,
          relevanceRule: PersonContextRelevanceRule.exactDecisionSubject,
          maxFreshness: Duration(days: 180),
          permittedField: PersonContextBehaviorField.supportingEvidence,
          effectSize: PersonContextEffectSize.evidenceOnly,
          conflictAuthority: PersonContextConflictAuthority.evidenceOnly,
          prohibitedInferences: _neverInferFromContext,
          overrideBehavior: PersonContextOverrideBehavior.evidenceOnly,
        ),
        PersonContextKind.value: PersonContextBehaviorRule._(
          kind: PersonContextKind.value,
          allowedSurfaces: _operationalSurfaces,
          purpose: PersonContextPurpose.decisionSupport,
          relevanceRule: PersonContextRelevanceRule.exactDecisionSubject,
          maxFreshness: Duration(days: 180),
          permittedField: PersonContextBehaviorField.supportingEvidence,
          effectSize: PersonContextEffectSize.evidenceOnly,
          conflictAuthority: PersonContextConflictAuthority.evidenceOnly,
          prohibitedInferences: _neverInferFromContext,
          overrideBehavior: PersonContextOverrideBehavior.evidenceOnly,
        ),
        PersonContextKind.currentPriority: PersonContextBehaviorRule._(
          kind: PersonContextKind.currentPriority,
          allowedSurfaces: _operationalSurfaces,
          purpose: PersonContextPurpose.decisionSupport,
          relevanceRule: PersonContextRelevanceRule.activePlanningWindow,
          maxFreshness: Duration(days: 30),
          permittedField: PersonContextBehaviorField.rankingPriority,
          effectSize: PersonContextEffectSize.tieBreak,
          conflictAuthority: PersonContextConflictAuthority.currentPriority,
          prohibitedInferences: _neverInferFromContext,
          overrideBehavior: PersonContextOverrideBehavior.tieBreakOnly,
        ),
        PersonContextKind.lifeArea: PersonContextBehaviorRule._(
          kind: PersonContextKind.lifeArea,
          allowedSurfaces: _operationalSurfaces,
          purpose: PersonContextPurpose.decisionSupport,
          relevanceRule: PersonContextRelevanceRule.exactDecisionSubject,
          maxFreshness: Duration(days: 180),
          permittedField: PersonContextBehaviorField.planningScope,
          effectSize: PersonContextEffectSize.boundedAdjustment,
          conflictAuthority: PersonContextConflictAuthority.evidenceOnly,
          prohibitedInferences: _neverInferFromContext,
          overrideBehavior: PersonContextOverrideBehavior.scopeOnly,
        ),
        PersonContextKind.presentCapacity: PersonContextBehaviorRule._(
          kind: PersonContextKind.presentCapacity,
          allowedSurfaces: _operationalSurfaces,
          purpose: PersonContextPurpose.decisionSupport,
          relevanceRule: PersonContextRelevanceRule.activePlanningWindow,
          maxFreshness: Duration(hours: 24),
          permittedField: PersonContextBehaviorField.capacityLimit,
          effectSize: PersonContextEffectSize.boundedAdjustment,
          conflictAuthority: PersonContextConflictAuthority.freshCapacity,
          prohibitedInferences: _neverInferFromContext,
          overrideBehavior: PersonContextOverrideBehavior.reduceOrRescopeOnly,
        ),
        PersonContextKind.preferredSupportStyle: PersonContextBehaviorRule._(
          kind: PersonContextKind.preferredSupportStyle,
          allowedSurfaces: _operationalSurfaces,
          purpose: PersonContextPurpose.planningGuidance,
          relevanceRule: PersonContextRelevanceRule.responsePresentation,
          maxFreshness: Duration(days: 180),
          permittedField: PersonContextBehaviorField.responseWording,
          effectSize: PersonContextEffectSize.presentationOnly,
          conflictAuthority: PersonContextConflictAuthority.preferenceOrWording,
          prohibitedInferences: _neverInferFromContext,
          overrideBehavior: PersonContextOverrideBehavior.wordingOnly,
        ),
        PersonContextKind.boundary: PersonContextBehaviorRule._(
          kind: PersonContextKind.boundary,
          allowedSurfaces: _operationalSurfaces,
          purpose: PersonContextPurpose.planningGuidance,
          relevanceRule: PersonContextRelevanceRule.explicitBoundary,
          maxFreshness: Duration(days: 180),
          permittedField: PersonContextBehaviorField.hardBoundary,
          effectSize: PersonContextEffectSize.constraint,
          conflictAuthority: PersonContextConflictAuthority.boundary,
          prohibitedInferences: _neverInferFromContext,
          overrideBehavior: PersonContextOverrideBehavior.hardBoundary,
        ),
        PersonContextKind.importantRelationship: PersonContextBehaviorRule._(
          kind: PersonContextKind.importantRelationship,
          allowedSurfaces: _operationalSurfaces,
          purpose: PersonContextPurpose.planningGuidance,
          relevanceRule: PersonContextRelevanceRule.exactDecisionSubject,
          maxFreshness: Duration(days: 180),
          permittedField: PersonContextBehaviorField.supportingEvidence,
          effectSize: PersonContextEffectSize.evidenceOnly,
          conflictAuthority: PersonContextConflictAuthority.evidenceOnly,
          prohibitedInferences: _neverInferFromContext,
          overrideBehavior: PersonContextOverrideBehavior.evidenceOnly,
        ),
        PersonContextKind.commitment: PersonContextBehaviorRule._(
          kind: PersonContextKind.commitment,
          allowedSurfaces: _operationalSurfaces,
          purpose: PersonContextPurpose.decisionSupport,
          relevanceRule: PersonContextRelevanceRule.explicitCommitment,
          maxFreshness: Duration(days: 30),
          permittedField: PersonContextBehaviorField.scheduledCommitment,
          effectSize: PersonContextEffectSize.constraint,
          conflictAuthority: PersonContextConflictAuthority.scheduledCommitment,
          prohibitedInferences: _neverInferFromContext,
          overrideBehavior: PersonContextOverrideBehavior.scheduleConstraint,
        ),
        PersonContextKind.outcomeHistory: PersonContextBehaviorRule._(
          kind: PersonContextKind.outcomeHistory,
          allowedSurfaces: _outcomeSurfaces,
          purpose: PersonContextPurpose.outcomeLearning,
          relevanceRule: PersonContextRelevanceRule.confirmedOutcome,
          maxFreshness: Duration(days: 90),
          permittedField: PersonContextBehaviorField.outcomeCalibration,
          effectSize: PersonContextEffectSize.boundedAdjustment,
          conflictAuthority: PersonContextConflictAuthority.evidenceOnly,
          prohibitedInferences: _neverInferFromContext,
          overrideBehavior: PersonContextOverrideBehavior.calibrationOnly,
        ),
      };

  static PersonContextBehaviorRule ruleFor(PersonContextKind kind) {
    final PersonContextBehaviorRule? rule = matrix[kind];
    if (rule == null) {
      throw StateError('Person Context behavior policy is incomplete.');
    }
    return rule;
  }

  static int conflictRank(PersonContextConflictAuthority authority) {
    final int index = conflictOrder.indexOf(authority);
    return index < 0 ? conflictOrder.length : index;
  }

  static int compareSignals(
    PersonContextSignal left,
    PersonContextSignal right,
  ) {
    final int authorityOrder = conflictRank(
      ruleFor(left.kind).conflictAuthority,
    ).compareTo(conflictRank(ruleFor(right.kind).conflictAuthority));
    if (authorityOrder != 0) return authorityOrder;
    final int kindOrder = left.kind.index.compareTo(right.kind.index);
    if (kindOrder != 0) return kindOrder;
    final int recordedOrder = right.recordedAt.toUtc().compareTo(
      left.recordedAt.toUtc(),
    );
    return recordedOrder != 0 ? recordedOrder : left.id.compareTo(right.id);
  }

  static PersonContextBehaviorTrace evaluate({
    required Iterable<PersonContextSignal> signals,
    required PersonContextSurface surface,
    required Set<PersonContextPurpose> purposes,
    required Map<String, PersonContextRelevanceBasis> relevance,
    required DateTime now,
    required Map<PersonContextBehaviorField, Object?> noContextBaseline,
    int? maxUsedSignals,
    bool safetyGateActive = false,
    Set<String> ignoredSignalIds = const <String>{},
    Set<String> supersededSignalIds = const <String>{},
  }) {
    if (purposes.isEmpty) {
      throw ArgumentError('Person Context behavior requires a purpose.');
    }
    if (maxUsedSignals != null && maxUsedSignals < 0) {
      throw ArgumentError.value(
        maxUsedSignals,
        'maxUsedSignals',
        'must not be negative',
      );
    }
    final DateTime observedAt = now.toUtc();
    final List<PersonContextSignal> orderedSignals = signals.toList()
      ..sort(compareSignals);
    final List<PersonContextBehaviorDecision> decisions =
        <PersonContextBehaviorDecision>[];
    final Set<PersonContextBehaviorField> claimedBehaviorFields =
        <PersonContextBehaviorField>{};
    int usedSignalCount = 0;
    for (final PersonContextSignal signal in orderedSignals) {
      final PersonContextBehaviorRule rule = ruleFor(signal.kind);
      final PersonContextRelevanceBasis? relevanceBasis = relevance[signal.id];
      PersonContextRejectionReason? rejection = _rejectionReason(
        signal: signal,
        rule: rule,
        surface: surface,
        purposes: purposes,
        relevanceBasis: relevanceBasis,
        now: observedAt,
      );
      if (ignoredSignalIds.contains(signal.id)) {
        rejection = PersonContextRejectionReason.userOverride;
      }
      if (rejection == null && supersededSignalIds.contains(signal.id)) {
        rejection = PersonContextRejectionReason.supersededByHigherAuthority;
      }
      if (rejection == null &&
          safetyGateActive &&
          conflictRank(rule.conflictAuthority) >
              conflictRank(PersonContextConflictAuthority.safety)) {
        rejection = PersonContextRejectionReason.safetyPreempted;
      }
      if (rejection == null &&
          rule.permittedField !=
              PersonContextBehaviorField.supportingEvidence &&
          claimedBehaviorFields.contains(rule.permittedField)) {
        rejection = PersonContextRejectionReason.supersededByHigherAuthority;
      }
      if (rejection == null &&
          maxUsedSignals != null &&
          usedSignalCount >= maxUsedSignals) {
        rejection = PersonContextRejectionReason.consumerLimitExceeded;
      }
      if (rejection == null) {
        usedSignalCount += 1;
        claimedBehaviorFields.add(rule.permittedField);
      }
      decisions.add(
        PersonContextBehaviorDecision._(
          signalId: signal.id,
          kind: signal.kind,
          status: rejection == null
              ? PersonContextDecisionStatus.used
              : PersonContextDecisionStatus.rejected,
          permittedField: rule.permittedField,
          effectSize: rejection == null
              ? rule.effectSize
              : PersonContextEffectSize.none,
          conflictAuthority: rule.conflictAuthority,
          overrideBehavior: rule.overrideBehavior,
          relevanceRule: rule.relevanceRule,
          relevanceBasis: relevanceBasis,
          rejectionReason: rejection,
        ),
      );
    }
    return PersonContextBehaviorTrace(
      surface: surface,
      purposes: purposes,
      observedAt: observedAt,
      noContextBaseline: noContextBaseline,
      decisions: decisions,
    );
  }

  /// Applies approved effects to a typed baseline and validates every actual
  /// changed field against the matrix decision that authorized it.
  ///
  /// Rejected signals cannot supply effects. The returned trace records only
  /// digests of before/after values so it explains the exact field delta
  /// without copying raw Person Context into logs or receipts.
  static PersonContextBehaviorApplication apply({
    required PersonContextBehaviorTrace trace,
    required Iterable<PersonContextBehaviorEffect> effects,
  }) {
    final Map<String, PersonContextBehaviorDecision> usedById =
        <String, PersonContextBehaviorDecision>{
          for (final PersonContextBehaviorDecision decision in trace.used)
            decision.signalId: decision,
        };
    final Map<String, PersonContextBehaviorEffect> effectById =
        <String, PersonContextBehaviorEffect>{};
    for (final PersonContextBehaviorEffect effect in effects) {
      final PersonContextBehaviorDecision? decision = usedById[effect.signalId];
      if (decision == null) {
        throw StateError(
          'Rejected or unknown Person Context cannot change behavior.',
        );
      }
      if (decision.permittedField != effect.field) {
        throw StateError(
          'Person Context attempted to change a field outside its policy.',
        );
      }
      if (effectById.containsKey(effect.signalId)) {
        throw StateError('Person Context supplied duplicate behavior effects.');
      }
      effectById[effect.signalId] = effect;
    }

    final Map<PersonContextBehaviorField, Object?> output =
        Map<PersonContextBehaviorField, Object?>.from(trace.noContextBaseline);
    final List<PersonContextBehaviorDelta> deltas =
        <PersonContextBehaviorDelta>[];
    for (final PersonContextBehaviorDecision decision in trace.used) {
      final PersonContextBehaviorEffect? effect = effectById[decision.signalId];
      if (effect == null) continue;
      final Object? before = output[effect.field];
      final String beforeDigest = evidenceContentDigest(before);
      final String afterDigest = evidenceContentDigest(effect.value);
      output[effect.field] = effect.value;
      deltas.add(
        PersonContextBehaviorDelta(
          signalId: effect.signalId,
          field: effect.field,
          effectSize: decision.effectSize,
          conflictAuthority: decision.conflictAuthority,
          beforeDigest: beforeDigest,
          afterDigest: afterDigest,
          changed: beforeDigest != afterDigest,
        ),
      );
    }
    return PersonContextBehaviorApplication(
      output: output,
      trace: trace.withAppliedDeltas(deltas),
    );
  }

  static PersonContextRejectionReason? _rejectionReason({
    required PersonContextSignal signal,
    required PersonContextBehaviorRule rule,
    required PersonContextSurface surface,
    required Set<PersonContextPurpose> purposes,
    required PersonContextRelevanceBasis? relevanceBasis,
    required DateTime now,
  }) {
    if (signal.purpose != rule.purpose || !purposes.contains(rule.purpose)) {
      return PersonContextRejectionReason.purposeNotAllowed;
    }
    if (!rule.allowedSurfaces.contains(surface)) {
      return PersonContextRejectionReason.surfaceNotAllowed;
    }
    if (!signal.surfaceScopes.contains(surface)) {
      return PersonContextRejectionReason.surfaceNotConsented;
    }
    if (signal.knowledge != PersonContextKnowledge.known) {
      return PersonContextRejectionReason.unknown;
    }
    if (signal.value.trim().isEmpty) {
      return PersonContextRejectionReason.empty;
    }
    if (signal.kind == PersonContextKind.outcomeHistory &&
        signal.source != PersonContextSource.confirmedOutcome) {
      return PersonContextRejectionReason.sourceNotAllowed;
    }
    if (signal.consent == PersonContextConsent.withdrawn) {
      return PersonContextRejectionReason.consentWithdrawn;
    }
    final DateTime? consentedAt = signal.consentedAt?.toUtc();
    if (consentedAt == null) {
      return PersonContextRejectionReason.consentMissing;
    }
    if (now.isBefore(consentedAt)) {
      return PersonContextRejectionReason.consentNotEffective;
    }
    final DateTime recordedAt = signal.recordedAt.toUtc();
    if (now.isBefore(recordedAt)) {
      return PersonContextRejectionReason.futureDated;
    }
    if (!now.isBefore(signal.expiresAt.toUtc())) {
      return PersonContextRejectionReason.expired;
    }
    if (!now.isBefore(signal.freshUntil.toUtc())) {
      return PersonContextRejectionReason.stale;
    }
    if (signal.freshUntil.toUtc().difference(recordedAt) > rule.maxFreshness) {
      return PersonContextRejectionReason.freshnessWindowExceeded;
    }
    if (!signal.isAvailableTo(surface, now)) {
      return PersonContextRejectionReason.unavailable;
    }
    if (relevanceBasis == null) {
      return PersonContextRejectionReason.irrelevant;
    }
    if (!_relevanceBasisIsAllowed(rule.relevanceRule, relevanceBasis)) {
      return PersonContextRejectionReason.invalidRelevanceBasis;
    }
    return null;
  }

  static bool _relevanceBasisIsAllowed(
    PersonContextRelevanceRule rule,
    PersonContextRelevanceBasis basis,
  ) {
    if (basis == PersonContextRelevanceBasis.typedReviewEvidence) return true;
    return switch (rule) {
      PersonContextRelevanceRule.exactDecisionSubject =>
        basis == PersonContextRelevanceBasis.exactTextMatch,
      PersonContextRelevanceRule.activePlanningWindow =>
        basis == PersonContextRelevanceBasis.exactTextMatch ||
            basis == PersonContextRelevanceBasis.typedActivePlanningWindow,
      PersonContextRelevanceRule.responsePresentation =>
        basis == PersonContextRelevanceBasis.typedResponsePresentation,
      PersonContextRelevanceRule.explicitBoundary =>
        basis == PersonContextRelevanceBasis.exactTextMatch ||
            basis == PersonContextRelevanceBasis.typedExplicitBoundary,
      PersonContextRelevanceRule.explicitCommitment =>
        basis == PersonContextRelevanceBasis.exactTextMatch ||
            basis == PersonContextRelevanceBasis.typedExplicitCommitment,
      PersonContextRelevanceRule.confirmedOutcome =>
        basis == PersonContextRelevanceBasis.exactTextMatch ||
            basis == PersonContextRelevanceBasis.typedConfirmedOutcome,
    };
  }
}
