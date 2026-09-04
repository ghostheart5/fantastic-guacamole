import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/milestone_entity.dart';
import 'package:fantastic_guacamole/domain/entities/person_context.dart';
import 'package:fantastic_guacamole/domain/entities/si_v2_contract.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/domain/policies/person_context_behavior_policy.dart';

typedef SIV2TaskReader = Future<List<TaskEntity>> Function();
typedef SIV2GoalReader = Future<List<GoalEntity>> Function();
typedef SIV2MilestoneReader = Future<List<MilestoneEntity>> Function();
typedef SIV2TimelineReader = Future<List<TimelineEventEntity>> Function();
typedef SIV2PersonContextReader = PersonContextView? Function();

/// The only domain capability available to SI V2.
///
/// This adapter intentionally exposes no save, update, delete, analytics,
/// Timeline-write, memory-write, XP, or proposal capability. It also strips
/// descriptions, notes, reflections, and Timeline detail before analysis so
/// retrieved user text cannot become an instruction channel. Person context is
/// copied into a bounded evidence DTO; the raw projection and governance history
/// never cross into SI V2.
final class SIV2ReadGateway {
  const SIV2ReadGateway({
    required this.accountScopeId,
    required this.readTasks,
    required this.readGoals,
    required this.readMilestones,
    required this.readTimeline,
    this.readPersonContext,
  });

  static const Set<PersonContextPurpose> personContextPurposes =
      operationalPersonContextPurposes;

  final String accountScopeId;
  final SIV2TaskReader readTasks;
  final SIV2GoalReader readGoals;
  final SIV2MilestoneReader readMilestones;
  final SIV2TimelineReader readTimeline;
  final SIV2PersonContextReader? readPersonContext;

  Future<SIV2EvidenceSnapshot> read({
    required DateTime observedAt,
    String decisionText = '',
  }) async {
    final Set<SIV2Source> unavailable = <SIV2Source>{};
    List<TaskEntity> taskEntities = const <TaskEntity>[];
    List<GoalEntity> goalEntities = const <GoalEntity>[];
    List<MilestoneEntity> milestoneEntities = const <MilestoneEntity>[];
    List<TimelineEventEntity> timelineEntities = const <TimelineEventEntity>[];
    PersonContextView? personContextView;

    try {
      taskEntities = await readTasks();
    } on Object {
      unavailable.add(SIV2Source.tasks);
    }
    try {
      goalEntities = await readGoals();
    } on Object {
      unavailable.add(SIV2Source.goals);
    }
    try {
      milestoneEntities = await readMilestones();
    } on Object {
      unavailable.add(SIV2Source.milestones);
    }
    try {
      timelineEntities = await readTimeline();
    } on Object {
      unavailable.add(SIV2Source.timeline);
    }
    try {
      personContextView = readPersonContext?.call();
    } on Object {
      personContextView = null;
    }

    final List<SIV2TaskEvidence> tasks =
        taskEntities
            .where(
              (TaskEntity item) =>
                  !item.isCompleted &&
                  !item.isSkipped &&
                  !item.isCanceled &&
                  item.title.trim().isNotEmpty,
            )
            .map(
              (TaskEntity item) => SIV2TaskEvidence(
                id: item.id,
                title: item.title.trim(),
                createdAt: item.createdAt.toUtc(),
                priority: item.priority,
                scheduledFor: item.scheduledFor?.toUtc(),
                dueDate: item.dueDate?.toUtc(),
                goalId: _trimToNull(item.goalId),
              ),
            )
            .toList(growable: false)
          ..sort(
            (SIV2TaskEvidence left, SIV2TaskEvidence right) =>
                left.id.compareTo(right.id),
          );
    final List<SIV2GoalEvidence> goals =
        goalEntities
            .where(
              (GoalEntity item) =>
                  item.isActive && item.title.trim().isNotEmpty,
            )
            .map(
              (GoalEntity item) => SIV2GoalEvidence(
                id: item.id,
                title: item.title.trim(),
                createdAt: item.createdAt.toUtc(),
                targetDate: item.targetDate?.toUtc(),
              ),
            )
            .toList(growable: false)
          ..sort(
            (SIV2GoalEvidence left, SIV2GoalEvidence right) =>
                left.id.compareTo(right.id),
          );
    final List<SIV2MilestoneEvidence> milestones =
        milestoneEntities
            .where((MilestoneEntity item) => item.title.trim().isNotEmpty)
            .map(
              (MilestoneEntity item) => SIV2MilestoneEvidence(
                id: item.id,
                title: item.title.trim(),
                createdAt: item.createdAt.toUtc(),
                updatedAt: item.updatedAt.toUtc(),
                completionPercent: item.completionPercent.clamp(0, 100),
                completed: item.isCompleted,
                archived: item.isArchived,
                goalId: _trimToNull(item.goalId),
                targetDate: item.targetDate?.toUtc(),
                dependencies: List<String>.unmodifiable(
                  item.dependencies
                      .map((String value) => value.trim())
                      .where((String value) => value.isNotEmpty),
                ),
              ),
            )
            .toList(growable: false)
          ..sort(
            (SIV2MilestoneEvidence left, SIV2MilestoneEvidence right) =>
                left.id.compareTo(right.id),
          );
    final List<SIV2TimelineEvidence> timeline =
        timelineEntities
            .where((TimelineEventEntity item) => item.title.trim().isNotEmpty)
            .map(
              (TimelineEventEntity item) => SIV2TimelineEvidence(
                id: item.id,
                title: item.title.trim(),
                timestamp: item.timestamp.toUtc(),
                type: item.type.name,
                status: item.status.name,
                dueAt: item.dueAt?.toUtc(),
                relatedId: _trimToNull(item.relatedId),
                sourceFeature: _trimToNull(item.sourceFeature),
              ),
            )
            .toList(growable: false)
          ..sort(
            (SIV2TimelineEvidence left, SIV2TimelineEvidence right) =>
                right.timestamp.compareTo(left.timestamp),
          );
    final SIV2PersonContextEvidence? personContext = decisionText.trim().isEmpty
        ? siV2PersonContextEvidenceOrNull(
            personContextView,
            accountScopeId: accountScopeId,
          )
        : _decisionPersonContextEvidenceOrNull(
            personContextView,
            accountScopeId: accountScopeId,
            tasks: taskEntities,
            decisionText: decisionText,
            observedAt: observedAt,
          );

    return SIV2EvidenceSnapshot(
      accountScopeId: accountScopeId,
      observedAt: observedAt.toUtc(),
      tasks: tasks,
      goals: goals,
      milestones: milestones,
      timeline: timeline,
      personContext: personContext,
      unavailableSources: unavailable,
    );
  }
}

SIV2PersonContextEvidence? _decisionPersonContextEvidenceOrNull(
  PersonContextView? view, {
  required String accountScopeId,
  required List<TaskEntity> tasks,
  required String decisionText,
  required DateTime observedAt,
}) {
  if (view == null || view.accountScopeId != accountScopeId) return null;
  final Set<PersonContextKind> relevantKinds = _relevantUnknownKinds(
    decisionText,
  );
  final GovernedDecisionContext context = GovernedDecisionContext.resolve(
    view: view,
    accountScopeId: accountScopeId,
    tasks: <TaskEntity>[
      TaskEntity(id: 'si-question', title: decisionText, createdAt: observedAt),
      ...tasks.where(
        (TaskEntity task) => _textOverlaps(task.title, decisionText),
      ),
    ],
    now: observedAt,
    surface: PersonContextSurface.siConsole,
    ignoredSignalIds: <String>{
      for (final PersonContextSignal signal in view.signals)
        if (signal.kind == PersonContextKind.presentCapacity &&
            !relevantKinds.contains(PersonContextKind.presentCapacity))
          signal.id,
    },
  );
  if (context.status == GovernedDecisionContextStatus.unavailable) return null;
  final List<SIV2PersonContextSignalEvidence> signals =
      view.signals
          .where(
            (PersonContextSignal signal) =>
                context.appliedSignalIds.contains(signal.id),
          )
          .map(
            (PersonContextSignal signal) => SIV2PersonContextSignalEvidence(
              id: signal.id,
              kind: signal.kind,
              userReportedValue: signal.value,
              source: signal.source,
              purpose: signal.purpose,
              recordedAt: signal.recordedAt.toUtc(),
              freshUntil: signal.freshUntil.toUtc(),
              expiresAt: signal.expiresAt.toUtc(),
            ),
          )
          .toList(growable: false)
        ..sort((left, right) => left.id.compareTo(right.id));
  return SIV2PersonContextEvidence(
    observedAt: view.observedAt.toUtc(),
    purposes: SIV2ReadGateway.personContextPurposes,
    signals: signals,
    unknownKinds: view.unknownKinds.intersection(relevantKinds),
    behaviorTrace: context.trace?.toJson() ?? const <String, Object?>{},
  );
}

Set<PersonContextKind> _relevantUnknownKinds(String decisionText) {
  final Set<String> words = _meaningfulWords(decisionText);
  return <PersonContextKind>{
    if (words.contains('next') ||
        words.contains('priority') ||
        words.contains('first'))
      PersonContextKind.currentPriority,
    if (words.contains('time') ||
        words.contains('capacity') ||
        words.contains('workload') ||
        words.contains('schedule'))
      PersonContextKind.presentCapacity,
    if (words.contains('schedule') || words.contains('plan'))
      PersonContextKind.boundary,
    if (words.contains('commitment') ||
        words.contains('schedule') ||
        words.contains('next'))
      PersonContextKind.commitment,
  };
}

bool _textOverlaps(String left, String right) =>
    _meaningfulWords(left).intersection(_meaningfulWords(right)).isNotEmpty;

Set<String> _meaningfulWords(String value) => RegExp(r'[a-z0-9]+')
    .allMatches(value.toLowerCase())
    .map((RegExpMatch match) => match.group(0)!)
    .where((String word) => word.length >= 4)
    .toSet();

SIV2PersonContextEvidence? siV2PersonContextEvidenceOrNull(
  PersonContextView? view, {
  required String accountScopeId,
}) {
  if (view == null ||
      view.accountScopeId != accountScopeId ||
      view.surface != PersonContextSurface.siConsole ||
      !_samePurposes(view.purposes, SIV2ReadGateway.personContextPurposes)) {
    return null;
  }
  try {
    final PersonContextBehaviorTrace evaluated =
        PersonContextBehaviorPolicy.evaluate(
          signals: view.signals,
          surface: PersonContextSurface.siConsole,
          purposes: view.purposes,
          relevance: <String, PersonContextRelevanceBasis>{
            for (final PersonContextSignal signal in view.signals)
              signal.id: PersonContextRelevanceBasis.typedReviewEvidence,
          },
          now: view.observedAt,
          noContextBaseline: const <PersonContextBehaviorField, Object?>{
            PersonContextBehaviorField.supportingEvidence: 'none',
          },
          maxUsedSignals: SIV2PersonContextEvidence.maxSignals,
        );
    final Set<String> approvedSignalIds = evaluated.used
        .map((PersonContextBehaviorDecision decision) => decision.signalId)
        .toSet();
    final List<SIV2PersonContextSignalEvidence> signals =
        view.signals
            .where(
              (PersonContextSignal signal) =>
                  approvedSignalIds.contains(signal.id),
            )
            .map(
              (PersonContextSignal signal) => SIV2PersonContextSignalEvidence(
                id: signal.id,
                kind: signal.kind,
                userReportedValue: signal.value,
                source: signal.source,
                purpose: signal.purpose,
                recordedAt: signal.recordedAt.toUtc(),
                freshUntil: signal.freshUntil.toUtc(),
                expiresAt: signal.expiresAt.toUtc(),
              ),
            )
            .toList(growable: false)
          ..sort(
            (
              SIV2PersonContextSignalEvidence left,
              SIV2PersonContextSignalEvidence right,
            ) => left.id.compareTo(right.id),
          );
    final Set<PersonContextKind> knownKinds = signals
        .map((SIV2PersonContextSignalEvidence signal) => signal.kind)
        .toSet();
    return SIV2PersonContextEvidence(
      observedAt: view.observedAt.toUtc(),
      purposes: SIV2ReadGateway.personContextPurposes,
      signals: signals,
      unknownKinds: PersonContextKind.values.toSet().difference(knownKinds),
    );
  } on Object {
    return null;
  }
}

bool _samePurposes(
  Set<PersonContextPurpose> left,
  Set<PersonContextPurpose> right,
) => left.length == right.length && left.containsAll(right);

String? _trimToNull(String? value) {
  final String normalized = value?.trim() ?? '';
  return normalized.isEmpty ? null : normalized;
}
