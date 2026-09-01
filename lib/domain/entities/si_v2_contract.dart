// CHRONOSPARK-CLASS: SHIPPING | Feature: SI Console V2
import 'dart:collection';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:fantastic_guacamole/domain/entities/person_context.dart';
import 'package:fantastic_guacamole/domain/operating_system/operating_system_contract.dart';
import 'package:fantastic_guacamole/domain/policies/assistant_safety_policy.dart';

const int siV2SchemaVersion = 1;

enum SIV2Intent {
  answer,
  explain,
  compare,
  forecast,
  findConflict,
  counterfactual,
}

enum SIV2Source { tasks, goals, milestones, timeline }

enum SIV2TimeRange { today, sevenDays, thirtyDays, all }

enum SIV2StatementKind { observedFact, deterministicCalculation, inference }

enum SIV2ConflictSeverity { notice, warning, critical }

enum SIV2ScenarioKind { doNow, deferOneDay, skip }

enum SIV2EvidenceStrength { limited, moderate, strong }

enum SIV2Freshness { current, aging, stale, unavailable }

extension SIV2IntentLabel on SIV2Intent {
  String get label => switch (this) {
    SIV2Intent.answer => 'Answer',
    SIV2Intent.explain => 'Explain',
    SIV2Intent.compare => 'Compare',
    SIV2Intent.forecast => 'Forecast',
    SIV2Intent.findConflict => 'Find conflict',
    SIV2Intent.counterfactual => 'Counterfactual',
  };
}

extension SIV2SourceLabel on SIV2Source {
  String get label => switch (this) {
    SIV2Source.tasks => 'Tasks',
    SIV2Source.goals => 'Goals',
    SIV2Source.milestones => 'Milestones',
    SIV2Source.timeline => 'Timeline',
  };
}

extension SIV2TimeRangeLabel on SIV2TimeRange {
  String get label => switch (this) {
    SIV2TimeRange.today => 'Today',
    SIV2TimeRange.sevenDays => '7 days',
    SIV2TimeRange.thirtyDays => '30 days',
    SIV2TimeRange.all => 'All time',
  };
}

final class SIV2Query {
  SIV2Query({
    this.schemaVersion = siV2SchemaVersion,
    required String rawText,
    required this.intent,
    required Set<SIV2Source> sources,
    required this.timeRange,
    String? entityFilter,
    List<String> assumptions = const <String>[],
    List<String> priorUserTurns = const <String>[],
  }) : rawText = rawText.trim(),
       sources = Set<SIV2Source>.unmodifiable(sources),
       entityFilter = _trimToNull(entityFilter),
       assumptions = List<String>.unmodifiable(
         assumptions
             .map((String item) => item.trim())
             .where((String item) => item.isNotEmpty),
       ),
       priorUserTurns = _normalizePriorUserTurns(priorUserTurns) {
    if (schemaVersion != siV2SchemaVersion || this.rawText.isEmpty) {
      throw ArgumentError('SI V2 queries require a supported schema and text.');
    }
    if (this.sources.isEmpty) {
      throw ArgumentError(
        'SI V2 queries require at least one evidence source.',
      );
    }
  }

  factory SIV2Query.fromUserInput({
    required String rawText,
    required SIV2Intent selectedIntent,
    required Set<SIV2Source> selectedSources,
    required SIV2TimeRange timeRange,
    String? entityFilter,
    String? scenarioAssumption,
    List<String> priorUserTurns = const <String>[],
  }) {
    final String normalized = rawText.trim().toLowerCase();
    final Set<SIV2Source> shortcutSources = <SIV2Source>{};
    if (normalized.startsWith('/tasks')) {
      shortcutSources.add(SIV2Source.tasks);
    }
    if (normalized.startsWith('/goals')) {
      shortcutSources.add(SIV2Source.goals);
    }
    if (normalized.startsWith('/milestones')) {
      shortcutSources.add(SIV2Source.milestones);
    }
    if (normalized.startsWith('/timeline')) {
      shortcutSources.add(SIV2Source.timeline);
    }
    final SIV2Intent detectedIntent = selectedIntent != SIV2Intent.answer
        ? selectedIntent
        : switch (normalized) {
            _
                when normalized.contains('what would change') ||
                    normalized.contains('counterfactual') =>
              SIV2Intent.counterfactual,
            _
                when normalized.contains('what happens') ||
                    normalized.contains('forecast') ||
                    normalized.contains('defer') ||
                    normalized.contains('delay') =>
              SIV2Intent.forecast,
            _
                when normalized.contains('conflict') ||
                    normalized.contains('contradict') =>
              SIV2Intent.findConflict,
            _
                when normalized.contains('compare') ||
                    normalized.contains('which goal') =>
              SIV2Intent.compare,
            _
                when normalized.startsWith('why') ||
                    normalized.contains('explain') =>
              SIV2Intent.explain,
            _ => selectedIntent,
          };
    return SIV2Query(
      rawText: rawText,
      intent: detectedIntent,
      sources: shortcutSources.isEmpty ? selectedSources : shortcutSources,
      timeRange: timeRange,
      entityFilter: entityFilter,
      assumptions: <String>[
        if (_trimToNull(scenarioAssumption) case final String assumption)
          assumption,
      ],
      priorUserTurns: priorUserTurns,
    );
  }

  final int schemaVersion;
  final String rawText;
  final SIV2Intent intent;
  final Set<SIV2Source> sources;
  final SIV2TimeRange timeRange;
  final String? entityFilter;
  final List<String> assumptions;
  final List<String> priorUserTurns;

  String get conversationText => <String>[...priorUserTurns, rawText].join(' ');
}

final class SIV2TaskEvidence {
  const SIV2TaskEvidence({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.priority,
    this.scheduledFor,
    this.dueDate,
    this.goalId,
  });

  final String id;
  final String title;
  final DateTime createdAt;
  final int priority;
  final DateTime? scheduledFor;
  final DateTime? dueDate;
  final String? goalId;
}

final class SIV2GoalEvidence {
  const SIV2GoalEvidence({
    required this.id,
    required this.title,
    required this.createdAt,
    this.targetDate,
  });

  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime? targetDate;
}

final class SIV2MilestoneEvidence {
  SIV2MilestoneEvidence({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.completionPercent,
    required this.completed,
    required this.archived,
    this.goalId,
    this.targetDate,
    List<String> dependencies = const <String>[],
  }) : dependencies = List<String>.unmodifiable(dependencies);

  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final double completionPercent;
  final bool completed;
  final bool archived;
  final String? goalId;
  final DateTime? targetDate;
  final List<String> dependencies;
}

final class SIV2TimelineEvidence {
  const SIV2TimelineEvidence({
    required this.id,
    required this.title,
    required this.timestamp,
    required this.type,
    required this.status,
    this.dueAt,
    this.relatedId,
    this.sourceFeature,
  });

  final String id;
  final String title;
  final DateTime timestamp;
  final String type;
  final String status;
  final DateTime? dueAt;
  final String? relatedId;
  final String? sourceFeature;
}

/// Bounded, read-only person context projected for the SI Console.
///
/// [userReportedValue] remains untrusted provenance. The current SI V2 engine
/// does not use it to construct an answer or expose it as answer evidence. It
/// must never be interpreted as an instruction or mutation request.
final class SIV2PersonContextSignalEvidence {
  SIV2PersonContextSignalEvidence({
    required String id,
    required this.kind,
    required String userReportedValue,
    required this.source,
    required this.purpose,
    required this.recordedAt,
    required this.freshUntil,
    required this.expiresAt,
  }) : id = id.trim(),
       userReportedValue = userReportedValue.trim().replaceAll(
         RegExp(r'\s+'),
         ' ',
       ) {
    if (this.id.isEmpty ||
        this.id.length > maxIdLength ||
        this.userReportedValue.isEmpty ||
        this.userReportedValue.length > maxValueLength) {
      throw ArgumentError('SI V2 person context evidence is malformed.');
    }
  }

  static const int maxIdLength = PersonContextSignal.maxIdLength;
  static const int maxValueLength = PersonContextSignal.maxValueLength;

  final String id;
  final PersonContextKind kind;
  final String userReportedValue;
  final PersonContextSource source;
  final PersonContextPurpose purpose;
  final DateTime recordedAt;
  final DateTime freshUntil;
  final DateTime expiresAt;
}

final class SIV2PersonContextEvidence {
  SIV2PersonContextEvidence({
    required this.observedAt,
    required Set<PersonContextPurpose> purposes,
    required List<SIV2PersonContextSignalEvidence> signals,
    required Set<PersonContextKind> unknownKinds,
  }) : purposes = Set<PersonContextPurpose>.unmodifiable(purposes),
       signals = List<SIV2PersonContextSignalEvidence>.unmodifiable(signals),
       unknownKinds = Set<PersonContextKind>.unmodifiable(unknownKinds) {
    if (this.purposes.isEmpty || this.signals.length > maxSignals) {
      throw ArgumentError('SI V2 person context evidence is unbounded.');
    }
    _validateEntityIdentity(
      this.signals.map(
        (SIV2PersonContextSignalEvidence item) =>
            (item.id, item.userReportedValue),
      ),
      'person context',
    );
  }

  static const int maxSignals = PersonContextSpine.maxSignals;

  final DateTime observedAt;
  final Set<PersonContextPurpose> purposes;
  final List<SIV2PersonContextSignalEvidence> signals;
  final Set<PersonContextKind> unknownKinds;

  bool get isEmpty => signals.isEmpty;
}

final class SIV2EvidenceSnapshot {
  SIV2EvidenceSnapshot({
    this.schemaVersion = siV2SchemaVersion,
    required String accountScopeId,
    required this.observedAt,
    required List<SIV2TaskEvidence> tasks,
    required List<SIV2GoalEvidence> goals,
    required List<SIV2MilestoneEvidence> milestones,
    required List<SIV2TimelineEvidence> timeline,
    this.personContext,
    Set<SIV2Source> unavailableSources = const <SIV2Source>{},
  }) : accountScopeId = accountScopeId.trim(),
       tasks = List<SIV2TaskEvidence>.unmodifiable(tasks),
       goals = List<SIV2GoalEvidence>.unmodifiable(goals),
       milestones = List<SIV2MilestoneEvidence>.unmodifiable(milestones),
       timeline = List<SIV2TimelineEvidence>.unmodifiable(timeline),
       unavailableSources = Set<SIV2Source>.unmodifiable(unavailableSources) {
    if (schemaVersion != siV2SchemaVersion || this.accountScopeId.isEmpty) {
      throw ArgumentError('SI V2 evidence must be account-bound.');
    }
    _validateEntityIdentity(
      this.tasks.map((SIV2TaskEvidence item) => (item.id, item.title)),
      'tasks',
    );
    _validateEntityIdentity(
      this.goals.map((SIV2GoalEvidence item) => (item.id, item.title)),
      'goals',
    );
    _validateEntityIdentity(
      this.milestones.map(
        (SIV2MilestoneEvidence item) => (item.id, item.title),
      ),
      'milestones',
    );
    _validateEntityIdentity(
      this.timeline.map((SIV2TimelineEvidence item) => (item.id, item.title)),
      'timeline',
    );
    if (this.milestones.any(
      (SIV2MilestoneEvidence item) =>
          item.completionPercent < 0 ||
          item.completionPercent > 100 ||
          item.dependencies.any((String value) => value.trim().isEmpty),
    )) {
      throw ArgumentError('SI V2 milestone evidence is malformed.');
    }
  }

  final int schemaVersion;
  final String accountScopeId;
  final DateTime observedAt;
  final List<SIV2TaskEvidence> tasks;
  final List<SIV2GoalEvidence> goals;
  final List<SIV2MilestoneEvidence> milestones;
  final List<SIV2TimelineEvidence> timeline;
  final SIV2PersonContextEvidence? personContext;
  final Set<SIV2Source> unavailableSources;

  String get revision => sha256
      .convert(
        utf8.encode(
          jsonEncode(<String, Object?>{
            'schema': schemaVersion,
            'account': accountScopeId,
            'observedAt': observedAt.toUtc().toIso8601String(),
            'goals': goals
                .map(
                  (SIV2GoalEvidence item) => <Object?>[
                    item.id,
                    item.title,
                    item.createdAt.toUtc().toIso8601String(),
                    item.targetDate?.toUtc().toIso8601String(),
                  ],
                )
                .toList(growable: false),
            'milestones': milestones
                .map(
                  (SIV2MilestoneEvidence item) => <Object?>[
                    item.id,
                    item.title,
                    item.createdAt.toUtc().toIso8601String(),
                    item.updatedAt.toUtc().toIso8601String(),
                    item.completionPercent,
                    item.completed,
                    item.archived,
                    item.goalId,
                    item.targetDate?.toUtc().toIso8601String(),
                    item.dependencies,
                  ],
                )
                .toList(growable: false),
            'tasks': tasks
                .map(
                  (SIV2TaskEvidence item) => <Object?>[
                    item.id,
                    item.title,
                    item.priority,
                    item.createdAt.toUtc().toIso8601String(),
                    item.dueDate?.toUtc().toIso8601String(),
                    item.scheduledFor?.toUtc().toIso8601String(),
                    item.goalId,
                  ],
                )
                .toList(growable: false),
            'timeline': timeline
                .map(
                  (SIV2TimelineEvidence item) => <Object?>[
                    item.id,
                    item.title,
                    item.timestamp.toUtc().toIso8601String(),
                    item.type,
                    item.status,
                    item.dueAt?.toUtc().toIso8601String(),
                    item.relatedId,
                    item.sourceFeature,
                  ],
                )
                .toList(growable: false),
            'personContext': personContext == null
                ? null
                : <String, Object?>{
                    'observedAt': personContext!.observedAt
                        .toUtc()
                        .toIso8601String(),
                    'purposes':
                        personContext!.purposes
                            .map((PersonContextPurpose purpose) => purpose.name)
                            .toList()
                          ..sort(),
                    'signals': personContext!.signals
                        .map(
                          (SIV2PersonContextSignalEvidence item) => <Object?>[
                            item.id,
                            item.kind.name,
                            item.userReportedValue,
                            item.source.name,
                            item.purpose.name,
                            item.recordedAt.toUtc().toIso8601String(),
                            item.freshUntil.toUtc().toIso8601String(),
                            item.expiresAt.toUtc().toIso8601String(),
                          ],
                        )
                        .toList(growable: false),
                    'unknownKinds':
                        personContext!.unknownKinds
                            .map((PersonContextKind kind) => kind.name)
                            .toList()
                          ..sort(),
                  },
            'unavailable':
                unavailableSources
                    .map((SIV2Source source) => source.name)
                    .toList()
                  ..sort(),
          }),
        ),
      )
      .toString();
}

final class SIV2EvidenceLink {
  const SIV2EvidenceLink({
    required this.evidenceId,
    required this.source,
    required this.label,
    required this.entityId,
    required this.observedAt,
    required this.uri,
  });

  final String evidenceId;
  final SIV2Source source;
  final String label;
  final String entityId;
  final DateTime observedAt;
  final String uri;
}

final class SIV2Statement {
  SIV2Statement({
    required this.kind,
    required String text,
    List<String> evidenceIds = const <String>[],
  }) : text = text.trim(),
       evidenceIds = List<String>.unmodifiable(evidenceIds) {
    if (this.text.isEmpty) {
      throw ArgumentError('SI V2 statements cannot be blank.');
    }
    if (kind != SIV2StatementKind.inference && this.evidenceIds.isEmpty) {
      throw ArgumentError('Facts and calculations require evidence links.');
    }
  }

  final SIV2StatementKind kind;
  final String text;
  final List<String> evidenceIds;
}

final class SIV2Conflict {
  SIV2Conflict({
    required String conflictId,
    required this.severity,
    required String summary,
    required List<String> evidenceIds,
  }) : conflictId = conflictId.trim(),
       summary = summary.trim(),
       evidenceIds = List<String>.unmodifiable(evidenceIds);

  final String conflictId;
  final SIV2ConflictSeverity severity;
  final String summary;
  final List<String> evidenceIds;
}

final class SIV2Scenario {
  SIV2Scenario({
    required this.kind,
    required String label,
    required String projectedEffect,
    required List<String> assumptions,
    required List<String> evidenceIds,
  }) : label = label.trim(),
       projectedEffect = projectedEffect.trim(),
       assumptions = List<String>.unmodifiable(
         assumptions.map((String item) => item.trim()),
       ),
       evidenceIds = List<String>.unmodifiable(evidenceIds);

  final SIV2ScenarioKind kind;
  final String label;
  final String projectedEffect;
  final List<String> assumptions;
  final List<String> evidenceIds;
}

final class SIV2ConfidenceAnatomy {
  const SIV2ConfidenceAnatomy({
    required this.strength,
    required this.coveredSignals,
    required this.requiredSignals,
    required this.freshness,
    required this.conflictCount,
    required this.assumptionCount,
  });

  final SIV2EvidenceStrength strength;
  final int coveredSignals;
  final int requiredSignals;
  final SIV2Freshness freshness;
  final int conflictCount;
  final int assumptionCount;
}

final class SIV2Response {
  SIV2Response({
    this.schemaVersion = siV2SchemaVersion,
    required this.query,
    required this.snapshotRevision,
    required String directAnswer,
    required List<SIV2Statement> observedFacts,
    required List<SIV2Statement> calculations,
    required List<SIV2Statement> inferences,
    required List<String> missingInformation,
    required List<SIV2Conflict> conflicts,
    required List<SIV2Scenario> scenarios,
    required List<String> scenarioAssumptions,
    required String recommendation,
    required this.confidence,
    required List<SIV2EvidenceLink> evidenceLinks,
    this.safetyReceipt,
  }) : directAnswer = directAnswer.trim(),
       observedFacts = List<SIV2Statement>.unmodifiable(observedFacts),
       calculations = List<SIV2Statement>.unmodifiable(calculations),
       inferences = List<SIV2Statement>.unmodifiable(inferences),
       missingInformation = List<String>.unmodifiable(missingInformation),
       conflicts = List<SIV2Conflict>.unmodifiable(conflicts),
       scenarios = List<SIV2Scenario>.unmodifiable(scenarios),
       scenarioAssumptions = List<String>.unmodifiable(scenarioAssumptions),
       recommendation = recommendation.trim(),
       evidenceLinks = List<SIV2EvidenceLink>.unmodifiable(evidenceLinks) {
    validate();
  }

  final int schemaVersion;
  final SIV2Query query;
  final String snapshotRevision;
  final String directAnswer;
  final List<SIV2Statement> observedFacts;
  final List<SIV2Statement> calculations;
  final List<SIV2Statement> inferences;
  final List<String> missingInformation;
  final List<SIV2Conflict> conflicts;
  final List<SIV2Scenario> scenarios;
  final List<String> scenarioAssumptions;
  final String recommendation;
  final SIV2ConfidenceAnatomy confidence;
  final List<SIV2EvidenceLink> evidenceLinks;
  final AssistantSafetyReceipt? safetyReceipt;

  SIV2Response withSafetyReceipt(AssistantSafetyReceipt receipt) =>
      SIV2Response(
        schemaVersion: schemaVersion,
        query: query,
        snapshotRevision: snapshotRevision,
        directAnswer: directAnswer,
        observedFacts: observedFacts,
        calculations: calculations,
        inferences: inferences,
        missingInformation: missingInformation,
        conflicts: conflicts,
        scenarios: scenarios,
        scenarioAssumptions: scenarioAssumptions,
        recommendation: recommendation,
        confidence: confidence,
        evidenceLinks: evidenceLinks,
        safetyReceipt: receipt,
      );

  SIV2Response withOperatingDecision(
    OperatingDecisionReceipt receipt, {
    DateTime? now,
  }) {
    if (receipt.isExpiredAt((now ?? DateTime.now()).toUtc())) return this;
    final SIV2EvidenceLink authorityLink = SIV2EvidenceLink(
      evidenceId: 'decision:${receipt.decisionId}',
      source: SIV2Source.tasks,
      label: 'Shared decision receipt',
      entityId: receipt.subjectId ?? receipt.planId,
      observedAt: receipt.generatedAt,
      uri: 'chronospark://decision/${receipt.decisionId}',
    );
    return SIV2Response(
      schemaVersion: schemaVersion,
      query: query,
      snapshotRevision: snapshotRevision,
      directAnswer: directAnswer,
      observedFacts: observedFacts,
      calculations: calculations,
      inferences: inferences,
      missingInformation: missingInformation,
      conflicts: conflicts,
      scenarios: scenarios,
      scenarioAssumptions: <String>[
        ...scenarioAssumptions,
        'The next action is read from shared decision plan ${receipt.planId}; SI Console did not independently rank another action.',
      ],
      recommendation: receipt.recommendedAction,
      confidence: confidence,
      evidenceLinks: <SIV2EvidenceLink>[
        ...evidenceLinks.where(
          (SIV2EvidenceLink item) =>
              item.evidenceId != authorityLink.evidenceId,
        ),
        authorityLink,
      ],
      safetyReceipt: safetyReceipt,
    );
  }

  void validate() {
    if (schemaVersion != siV2SchemaVersion ||
        directAnswer.isEmpty ||
        recommendation.isEmpty ||
        snapshotRevision.length != 64) {
      throw StateError('SI V2 response contract is incomplete.');
    }
    if (confidence.coveredSignals < 0 ||
        confidence.requiredSignals <= 0 ||
        confidence.coveredSignals > confidence.requiredSignals) {
      throw StateError('SI V2 confidence anatomy has invalid coverage.');
    }
    final Set<String> linkIds = evidenceLinks
        .map((SIV2EvidenceLink item) => item.evidenceId)
        .toSet();
    if (linkIds.length != evidenceLinks.length ||
        evidenceLinks.any(
          (SIV2EvidenceLink item) =>
              item.evidenceId.trim().isEmpty ||
              item.label.trim().isEmpty ||
              item.entityId.trim().isEmpty ||
              !item.uri.startsWith('chronospark://'),
        )) {
      throw StateError('SI V2 evidence links must be unique and inspectable.');
    }
    if (observedFacts.any(
          (SIV2Statement item) => item.kind != SIV2StatementKind.observedFact,
        ) ||
        calculations.any(
          (SIV2Statement item) =>
              item.kind != SIV2StatementKind.deterministicCalculation,
        ) ||
        inferences.any(
          (SIV2Statement item) => item.kind != SIV2StatementKind.inference,
        )) {
      throw StateError('SI V2 statements are in the wrong response section.');
    }
    if (conflicts.any(
          (SIV2Conflict item) =>
              item.conflictId.trim().isEmpty ||
              item.summary.trim().isEmpty ||
              item.evidenceIds.isEmpty,
        ) ||
        scenarios.any(
          (SIV2Scenario item) =>
              item.label.trim().isEmpty ||
              item.projectedEffect.trim().isEmpty ||
              item.assumptions.isEmpty ||
              item.evidenceIds.isEmpty,
        )) {
      throw StateError('SI V2 conflicts and scenarios require evidence.');
    }
    if (missingInformation.any((String item) => item.trim().isEmpty) ||
        scenarioAssumptions.any((String item) => item.trim().isEmpty)) {
      throw StateError('SI V2 response lists cannot contain blank entries.');
    }
    final Iterable<String> citedIds = <Iterable<String>>[
      observedFacts.expand((SIV2Statement item) => item.evidenceIds),
      calculations.expand((SIV2Statement item) => item.evidenceIds),
      inferences.expand((SIV2Statement item) => item.evidenceIds),
      conflicts.expand((SIV2Conflict item) => item.evidenceIds),
      scenarios.expand((SIV2Scenario item) => item.evidenceIds),
    ].expand((Iterable<String> ids) => ids);
    if (!linkIds.containsAll(citedIds)) {
      throw StateError('SI V2 response cites evidence outside its lens.');
    }
    if (safetyReceipt != null &&
        (safetyReceipt!.surface != AssistantSafetySurface.siConsole ||
            safetyReceipt!.disposition == AssistantSafetyDisposition.withheld ||
            safetyReceipt!.disposition ==
                AssistantSafetyDisposition.crisisRoute)) {
      throw StateError('SI V2 response has an invalid safety receipt.');
    }
  }

  String toPlainText() {
    String statements(List<SIV2Statement> values) => values.isEmpty
        ? '- None available'
        : values.map((SIV2Statement item) => '- ${item.text}').join('\n');
    return 'DIRECT ANSWER\n$directAnswer\n\n'
        'OBSERVED FACTS\n${statements(observedFacts)}\n\n'
        'DETERMINISTIC CALCULATIONS\n${statements(calculations)}\n\n'
        'INFERENCES\n${statements(inferences)}\n\n'
        'MISSING OR CONFLICTING INFORMATION\n'
        '${missingInformation.isEmpty ? '- None identified' : missingInformation.map((String item) => '- $item').join('\n')}\n\n'
        'SCENARIOS\n'
        '${scenarios.isEmpty ? '- None available' : scenarios.map((SIV2Scenario item) => '- ${item.label}: ${item.projectedEffect}').join('\n')}\n\n'
        'SCENARIO ASSUMPTIONS\n'
        '${scenarioAssumptions.isEmpty ? '- None' : scenarioAssumptions.map((String item) => '- $item').join('\n')}\n\n'
        'RECOMMENDATION\n$recommendation\n\n'
        'CONFIDENCE ANATOMY\n'
        'Evidence strength: ${confidence.strength.name}\n'
        'Coverage: ${confidence.coveredSignals} of ${confidence.requiredSignals} required signals\n'
        'Freshness: ${confidence.freshness.name}\n'
        'Conflicts: ${confidence.conflictCount}\n'
        'Assumptions: ${confidence.assumptionCount}\n\n'
        'EVIDENCE LINKS\n'
        '${evidenceLinks.isEmpty ? '- None available' : evidenceLinks.map((SIV2EvidenceLink item) => '- ${item.label} — ${item.uri}').join('\n')}';
  }
}

String? _trimToNull(String? value) {
  final String normalized = value?.trim() ?? '';
  return normalized.isEmpty ? null : normalized;
}

List<String> _normalizePriorUserTurns(List<String> values) {
  final List<String> normalized = values
      .map((String value) => value.replaceAll(RegExp(r'\s+'), ' ').trim())
      .where((String value) => value.isNotEmpty)
      .map(
        (String value) => value.length <= 240
            ? value
            : '${value.substring(0, 239).trimRight()}…',
      )
      .toList(growable: false);
  final List<String> bounded = normalized.length <= 4
      ? normalized
      : normalized.sublist(normalized.length - 4);
  return List<String>.unmodifiable(bounded);
}

void _validateEntityIdentity(
  Iterable<(String, String)> identities,
  String source,
) {
  final List<(String, String)> values = identities.toList(growable: false);
  final Set<String> ids = values
      .map(((String, String) item) => item.$1)
      .toSet();
  if (ids.length != values.length ||
      values.any(
        ((String, String) item) =>
            item.$1.trim().isEmpty || item.$2.trim().isEmpty,
      )) {
    throw ArgumentError('SI V2 $source evidence has invalid identity.');
  }
}

UnmodifiableSetView<SIV2Source> get allSIV2Sources =>
    UnmodifiableSetView<SIV2Source>(SIV2Source.values.toSet());
