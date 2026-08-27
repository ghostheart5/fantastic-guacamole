import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/milestone_entity.dart';
import 'package:fantastic_guacamole/domain/entities/si_v2_contract.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';

typedef SIV2TaskReader = Future<List<TaskEntity>> Function();
typedef SIV2GoalReader = Future<List<GoalEntity>> Function();
typedef SIV2MilestoneReader = Future<List<MilestoneEntity>> Function();
typedef SIV2TimelineReader = Future<List<TimelineEventEntity>> Function();

/// The only domain capability available to SI V2.
///
/// This adapter intentionally exposes no save, update, delete, analytics,
/// Timeline-write, memory-write, XP, or proposal capability. It also strips
/// descriptions, notes, reflections, and Timeline detail before analysis so
/// retrieved user text cannot become an instruction channel.
final class SIV2ReadGateway {
  const SIV2ReadGateway({
    required this.accountScopeId,
    required this.readTasks,
    required this.readGoals,
    required this.readMilestones,
    required this.readTimeline,
  });

  final String accountScopeId;
  final SIV2TaskReader readTasks;
  final SIV2GoalReader readGoals;
  final SIV2MilestoneReader readMilestones;
  final SIV2TimelineReader readTimeline;

  Future<SIV2EvidenceSnapshot> read({required DateTime observedAt}) async {
    final Set<SIV2Source> unavailable = <SIV2Source>{};
    List<TaskEntity> taskEntities = const <TaskEntity>[];
    List<GoalEntity> goalEntities = const <GoalEntity>[];
    List<MilestoneEntity> milestoneEntities = const <MilestoneEntity>[];
    List<TimelineEventEntity> timelineEntities = const <TimelineEventEntity>[];

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

    return SIV2EvidenceSnapshot(
      accountScopeId: accountScopeId,
      observedAt: observedAt.toUtc(),
      tasks: tasks,
      goals: goals,
      milestones: milestones,
      timeline: timeline,
      unavailableSources: unavailable,
    );
  }
}

String? _trimToNull(String? value) {
  final String normalized = value?.trim() ?? '';
  return normalized.isEmpty ? null : normalized;
}
