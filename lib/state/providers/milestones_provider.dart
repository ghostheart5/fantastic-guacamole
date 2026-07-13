import 'dart:convert';

import 'package:fantastic_guacamole/core/eventing/domain_event.dart';
import 'package:fantastic_guacamole/data/di/storage_providers.dart';
import 'package:fantastic_guacamole/domain/entities/milestone_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task.dart';
import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/event_bus_provider.dart';
import 'package:fantastic_guacamole/state/providers/task_provider.dart';
import 'package:fantastic_guacamole/state/providers/timeline_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MilestoneSummary {
  const MilestoneSummary({
    required this.total,
    required this.active,
    required this.completed,
    required this.overdue,
    required this.upcoming,
    required this.healthScore,
    required this.momentumScore,
    required this.riskScore,
    required this.completionRate,
    required this.nextMilestone,
    required this.closestMilestone,
    required this.highestPriority,
  });

  final int total;
  final int active;
  final int completed;
  final int overdue;
  final int upcoming;
  final int healthScore;
  final int momentumScore;
  final int riskScore;
  final double completionRate;
  final MilestoneEntity? nextMilestone;
  final MilestoneEntity? closestMilestone;
  final MilestoneEntity? highestPriority;
}

class MilestoneRisk {
  const MilestoneRisk({
    required this.milestone,
    required this.reason,
    required this.recommendation,
    required this.daysBehind,
    required this.riskWeight,
  });

  final MilestoneEntity milestone;
  final String reason;
  final String recommendation;
  final int daysBehind;
  final int riskWeight;
}

class MilestoneForecast {
  const MilestoneForecast({
    required this.milestone,
    required this.predictedCompletionDate,
    required this.delayDays,
    required this.successRate,
    required this.confidence,
  });

  final MilestoneEntity milestone;
  final DateTime predictedCompletionDate;
  final int delayDays;
  final int successRate;
  final int confidence;
}

final milestonesProvider =
    AsyncNotifierProvider<MilestonesNotifier, List<MilestoneEntity>>(
      MilestonesNotifier.new,
    );

final milestoneActionsProvider = Provider<MilestoneActions>((Ref ref) {
  return MilestoneActions(ref);
});

final milestoneSearchProvider = Provider.family<List<MilestoneEntity>, String>((
  Ref ref,
  String query,
) {
  final String q = query.trim().toLowerCase();
  final List<MilestoneEntity> milestones =
      ref.watch(milestonesProvider).asData?.value ?? const <MilestoneEntity>[];
  if (q.isEmpty) {
    return milestones;
  }
  return milestones
      .where((MilestoneEntity item) {
        return item.title.toLowerCase().contains(q) ||
            (item.description?.toLowerCase().contains(q) ?? false) ||
            (item.note?.toLowerCase().contains(q) ?? false) ||
            (item.reflection?.toLowerCase().contains(q) ?? false);
      })
      .toList(growable: false);
});

final milestonesByCategoryProvider =
    Provider<Map<MilestoneCategory, List<MilestoneEntity>>>((Ref ref) {
      final List<MilestoneEntity> milestones =
          ref.watch(milestonesProvider).asData?.value ??
          const <MilestoneEntity>[];
      final Map<MilestoneCategory, List<MilestoneEntity>> grouped = {
        for (final MilestoneCategory category in MilestoneCategory.values)
          category: <MilestoneEntity>[],
      };
      for (final MilestoneEntity milestone in milestones) {
        grouped[milestone.category]!.add(milestone);
      }
      return grouped;
    });

final milestoneCompletedProvider = Provider<List<MilestoneEntity>>((Ref ref) {
  final List<MilestoneEntity> milestones =
      ref.watch(milestonesProvider).asData?.value ?? const <MilestoneEntity>[];
  return milestones
      .where((MilestoneEntity item) => item.isCompleted)
      .toList(growable: false);
});

final milestoneUpcomingProvider = Provider<List<MilestoneEntity>>((Ref ref) {
  final List<MilestoneEntity> milestones =
      ref.watch(milestonesProvider).asData?.value ?? const <MilestoneEntity>[];
  return milestones
      .where((MilestoneEntity item) => item.isUpcoming)
      .toList(growable: false)
    ..sort(
      (a, b) => (a.targetDate ?? DateTime(2100)).compareTo(
        b.targetDate ?? DateTime(2100),
      ),
    );
});

final milestoneOverdueProvider = Provider<List<MilestoneEntity>>((Ref ref) {
  final List<MilestoneEntity> milestones =
      ref.watch(milestonesProvider).asData?.value ?? const <MilestoneEntity>[];
  return milestones
      .where((MilestoneEntity item) => item.isOverdue)
      .toList(growable: false)
    ..sort(
      (a, b) => (a.targetDate ?? DateTime(1900)).compareTo(
        b.targetDate ?? DateTime(1900),
      ),
    );
});

final milestoneRisksProvider = Provider<List<MilestoneRisk>>((Ref ref) {
  final DateTime now = DateTime.now();
  final List<MilestoneEntity> milestones =
      ref.watch(milestonesProvider).asData?.value ?? const <MilestoneEntity>[];
  final List<Task> tasks =
      ref.watch(tasksProvider).asData?.value ?? const <Task>[];
  final List<MilestoneRisk> risks = <MilestoneRisk>[];

  for (final MilestoneEntity milestone in milestones.where(
    (MilestoneEntity item) => item.isActive,
  )) {
    final DateTime? due = milestone.targetDate;
    final bool hasLinkedTasks = milestone.goalId == null
        ? true
        : tasks.any((Task task) => task.goalId == milestone.goalId);

    if (milestone.isOverdue && due != null) {
      final int daysBehind = now.difference(due).inDays.abs();
      risks.add(
        MilestoneRisk(
          milestone: milestone,
          reason: 'Milestone overdue.',
          recommendation:
              'Prioritize this milestone immediately and recover schedule this week.',
          daysBehind: daysBehind,
          riskWeight: (70 + (daysBehind * 2)).clamp(70, 100),
        ),
      );
      continue;
    }

    if (!hasLinkedTasks) {
      risks.add(
        MilestoneRisk(
          milestone: milestone,
          reason: 'Milestone has no linked active tasks.',
          recommendation:
              'Create linked tasks so this milestone can move forward.',
          daysBehind: 0,
          riskWeight: 68,
        ),
      );
      continue;
    }

    if (due != null) {
      final int totalHours = due.difference(milestone.createdAt).inHours;
      if (totalHours > 0) {
        final int elapsedHours = now
            .difference(milestone.createdAt)
            .inHours
            .clamp(0, totalHours);
        final double expectedPercent = (elapsedHours / totalHours) * 100;
        if (milestone.completionPercent + 8 < expectedPercent) {
          risks.add(
            MilestoneRisk(
              milestone: milestone,
              reason: 'Milestone is behind expected pace.',
              recommendation:
                  'Increase milestone effort blocks and reduce low-impact work.',
              daysBehind: 0,
              riskWeight: 62,
            ),
          );
        }
      }
    }
  }

  risks.sort(
    (MilestoneRisk a, MilestoneRisk b) => b.riskWeight.compareTo(a.riskWeight),
  );
  return risks;
});

final milestoneForecastsProvider = Provider<List<MilestoneForecast>>((Ref ref) {
  final DateTime now = DateTime.now();
  final List<MilestoneEntity> milestones =
      ref.watch(milestonesProvider).asData?.value ?? const <MilestoneEntity>[];
  final List<MilestoneForecast> output = <MilestoneForecast>[];

  for (final MilestoneEntity milestone in milestones.where(
    (MilestoneEntity item) => item.isActive && item.targetDate != null,
  )) {
    final DateTime targetDate = milestone.targetDate!;
    final int elapsedDays = now
        .difference(milestone.createdAt)
        .inDays
        .clamp(1, 36500);
    final double percent = milestone.completionPercent.clamp(0, 100);
    final double perDay = percent <= 0 ? 0 : percent / elapsedDays;

    DateTime predicted = targetDate;
    if (percent >= 100) {
      predicted = now;
    } else if (perDay > 0) {
      final int remainingDays = ((100 - percent) / perDay).ceil();
      predicted = DateTime(
        now.year,
        now.month,
        now.day,
      ).add(Duration(days: remainingDays));
    } else {
      predicted = targetDate.add(const Duration(days: 21));
    }

    final int delayDays = predicted.isAfter(targetDate)
        ? predicted.difference(targetDate).inDays
        : 0;
    final int successRate = (100 - (delayDays * 3) - ((100 - percent) ~/ 4))
        .clamp(0, 100);
    final int confidence = (percent > 0 ? 82 : 64) - (delayDays > 0 ? 10 : 0);

    output.add(
      MilestoneForecast(
        milestone: milestone,
        predictedCompletionDate: predicted,
        delayDays: delayDays,
        successRate: successRate,
        confidence: confidence.clamp(35, 95),
      ),
    );
  }

  output.sort((MilestoneForecast a, MilestoneForecast b) {
    return a.predictedCompletionDate.compareTo(b.predictedCompletionDate);
  });
  return output;
});

final milestoneSummaryProvider = Provider<MilestoneSummary>((Ref ref) {
  final List<MilestoneEntity> milestones =
      ref.watch(milestonesProvider).asData?.value ?? const <MilestoneEntity>[];
  final List<MilestoneEntity> risks = ref
      .watch(milestoneRisksProvider)
      .map((MilestoneRisk item) => item.milestone)
      .toList(growable: false);
  final int total = milestones.length;
  final int completed = milestones
      .where((MilestoneEntity item) => item.isCompleted)
      .length;
  final int active = milestones
      .where((MilestoneEntity item) => item.isActive)
      .length;
  final int overdue = milestones
      .where((MilestoneEntity item) => item.isOverdue)
      .length;
  final int upcoming = milestones
      .where((MilestoneEntity item) => item.isUpcoming)
      .length;

  final double completionRate = total == 0 ? 0 : (completed / total) * 100;
  final int healthScore =
      (100 - (overdue * 14) - (risks.length * 9) + (completed * 4)).clamp(
        0,
        100,
      );
  final int momentumScore =
      ((completionRate * 0.6) + (upcoming > 0 ? 20 : 8) - (overdue * 2))
          .round()
          .clamp(0, 100);
  final int riskScore = (100 - healthScore).clamp(0, 100);

  MilestoneEntity? closest;
  MilestoneEntity? highest;
  MilestoneEntity? next;

  final List<MilestoneEntity> activeList = milestones
      .where((MilestoneEntity item) => item.isActive)
      .toList(growable: false);
  final List<MilestoneEntity> sortedUpcoming =
      activeList
          .where(
            (MilestoneEntity item) =>
                item.targetDate != null &&
                !item.targetDate!.isBefore(DateTime.now()),
          )
          .toList(growable: false)
        ..sort(
          (a, b) => (a.targetDate ?? DateTime(2100)).compareTo(
            b.targetDate ?? DateTime(2100),
          ),
        );
  if (sortedUpcoming.isNotEmpty) {
    next = sortedUpcoming.first;
  }
  for (final MilestoneEntity item in activeList) {
    if (closest == null) {
      closest = item;
    } else {
      final DateTime current = item.targetDate ?? DateTime(2100);
      final DateTime previous = closest.targetDate ?? DateTime(2100);
      if (current.isBefore(previous)) {
        closest = item;
      }
    }
    if (highest == null || item.priority.index > highest.priority.index) {
      highest = item;
    }
  }

  return MilestoneSummary(
    total: total,
    active: active,
    completed: completed,
    overdue: overdue,
    upcoming: upcoming,
    healthScore: healthScore,
    momentumScore: momentumScore,
    riskScore: riskScore,
    completionRate: completionRate,
    nextMilestone: next,
    closestMilestone: closest,
    highestPriority: highest,
  );
});

class MilestoneActions {
  const MilestoneActions(this._ref);

  final Ref _ref;

  Future<void> createMilestone({
    required String title,
    String? description,
    String? goalId,
    String? projectId,
    String? habitId,
    MilestoneCategory category = MilestoneCategory.other,
    MilestonePriority priority = MilestonePriority.medium,
    DateTime? targetDate,
    String? reward,
    String? note,
    DateTime? reminderAt,
    List<String> dependencies = const <String>[],
  }) {
    return _ref
        .read(milestonesProvider.notifier)
        .create(
          title: title,
          description: description,
          goalId: goalId,
          projectId: projectId,
          habitId: habitId,
          category: category,
          priority: priority,
          targetDate: targetDate,
          reward: reward,
          note: note,
          reminderAt: reminderAt,
          dependencies: dependencies,
        );
  }

  Future<void> updateProgress(String id, double completionPercent) {
    return _ref
        .read(milestonesProvider.notifier)
        .updateProgress(id, completionPercent);
  }

  Future<void> complete(String id, {String? reflection}) {
    return _ref
        .read(milestonesProvider.notifier)
        .complete(id, reflection: reflection);
  }

  Future<void> archive(String id) {
    return _ref.read(milestonesProvider.notifier).archive(id);
  }

  Future<void> remove(String id) {
    return _ref.read(milestonesProvider.notifier).remove(id);
  }
}

class MilestonesNotifier extends AsyncNotifier<List<MilestoneEntity>> {
  static const String _storageKey = 'milestones_v1';

  @override
  Future<List<MilestoneEntity>> build() async {
    return _loadMilestones();
  }

  Future<void> create({
    required String title,
    String? description,
    String? goalId,
    String? projectId,
    String? habitId,
    MilestoneCategory category = MilestoneCategory.other,
    MilestonePriority priority = MilestonePriority.medium,
    DateTime? targetDate,
    String? reward,
    String? note,
    DateTime? reminderAt,
    List<String> dependencies = const <String>[],
  }) async {
    final String trimmed = title.trim();
    if (trimmed.isEmpty) {
      return;
    }
    final List<MilestoneEntity> current = _current();
    final DateTime now = DateTime.now();
    final MilestoneEntity milestone = MilestoneEntity(
      id: now.microsecondsSinceEpoch.toString(),
      goalId: goalId,
      projectId: projectId,
      habitId: habitId,
      title: trimmed,
      description: description?.trim(),
      category: category,
      priority: priority,
      targetDate: targetDate,
      reward: reward?.trim(),
      note: note?.trim(),
      reminderAt: reminderAt,
      dependencies: dependencies,
      createdAt: now,
      updatedAt: now,
    );

    final List<MilestoneEntity> next = <MilestoneEntity>[milestone, ...current];
    await _persist(next);
    state = AsyncData(next);
    await _recordTimelineEvent(
      type: TimelineEventType.milestone,
      title: 'Milestone Created',
      detail: milestone.title,
      dueAt: milestone.targetDate,
      status: TimelineEventStatus.planned,
      relatedId: milestone.id,
    );
    await _refreshCoachDecision();
  }

  Future<void> updateMilestone(MilestoneEntity updated) async {
    final List<MilestoneEntity> current = _current();
    final DateTime now = DateTime.now();
    final List<MilestoneEntity> next = current
        .map(
          (MilestoneEntity item) =>
              item.id == updated.id ? updated.copyWith(updatedAt: now) : item,
        )
        .toList(growable: false);
    await _persist(next);
    state = AsyncData(next);
    await _refreshCoachDecision();
  }

  Future<void> updateProgress(String id, double completionPercent) async {
    final List<MilestoneEntity> current = _current();
    final DateTime now = DateTime.now();
    final double clamped = completionPercent.clamp(0, 100);
    MilestoneEntity? target;
    final List<MilestoneEntity> next = current
        .map((MilestoneEntity item) {
          if (item.id != id) {
            return item;
          }
          final MilestoneStatus status = clamped >= 100
              ? MilestoneStatus.completed
              : item.isOverdue
              ? MilestoneStatus.overdue
              : MilestoneStatus.inProgress;
          target = item.copyWith(
            completionPercent: clamped,
            status: status,
            completedAt: clamped >= 100 ? now : item.completedAt,
            updatedAt: now,
          );
          return target!;
        })
        .toList(growable: false);

    await _persist(next);
    state = AsyncData(next);

    if (target != null && target!.isCompleted) {
      await _recordTimelineEvent(
        type: TimelineEventType.milestone,
        title: 'Milestone Achieved',
        detail: target!.title,
        dueAt: target!.targetDate,
        status: TimelineEventStatus.completed,
        relatedId: target!.id,
      );
    }
    await _refreshCoachDecision();
  }

  Future<void> complete(String id, {String? reflection}) async {
    final List<MilestoneEntity> current = _current();
    final DateTime now = DateTime.now();
    MilestoneEntity? completed;

    final List<MilestoneEntity> next = current
        .map((MilestoneEntity item) {
          if (item.id != id) {
            return item;
          }
          completed = item.copyWith(
            status: MilestoneStatus.completed,
            completionPercent: 100,
            reflection: reflection?.trim() ?? item.reflection,
            completedAt: now,
            updatedAt: now,
          );
          return completed!;
        })
        .toList(growable: false);

    await _persist(next);
    state = AsyncData(next);

    if (completed != null) {
      await _recordTimelineEvent(
        type: TimelineEventType.milestone,
        title: 'Milestone Achieved',
        detail: completed!.title,
        dueAt: completed!.targetDate,
        status: TimelineEventStatus.completed,
        relatedId: completed!.id,
      );
      ref
          .read(eventBusProvider)
          .emit(
            TimelineLifecycleEvent(
              eventId: 'milestone-achieved-${completed!.id}',
              title: completed!.title,
              type: TimelineEventType.milestone.name,
            ),
          );
    }
    await _refreshCoachDecision();
  }

  Future<void> archive(String id) async {
    final List<MilestoneEntity> current = _current();
    final DateTime now = DateTime.now();
    final List<MilestoneEntity> next = current
        .map(
          (MilestoneEntity item) => item.id == id
              ? item.copyWith(
                  status: MilestoneStatus.archived,
                  archivedAt: now,
                  updatedAt: now,
                )
              : item,
        )
        .toList(growable: false);
    await _persist(next);
    state = AsyncData(next);
  }

  Future<void> remove(String id) async {
    final List<MilestoneEntity> current = _current();
    final List<MilestoneEntity> next = current
        .where((MilestoneEntity item) => item.id != id)
        .toList(growable: false);
    await _persist(next);
    state = AsyncData(next);
  }

  List<MilestoneEntity> _current() {
    final AsyncValue<List<MilestoneEntity>> current = state;
    return current.asData?.value.toList(growable: false) ??
        const <MilestoneEntity>[];
  }

  Future<List<MilestoneEntity>> _loadMilestones() async {
    final String? raw = await ref
        .read(secureStoreProvider)
        .readString(_storageKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <MilestoneEntity>[];
    }
    final dynamic decoded = jsonDecode(raw);
    if (decoded is! List<dynamic>) {
      return const <MilestoneEntity>[];
    }
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(MilestoneEntity.fromJson)
        .toList(growable: false)
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  Future<void> _persist(List<MilestoneEntity> milestones) {
    final String payload = jsonEncode(
      milestones
          .map((MilestoneEntity item) => item.toJson())
          .toList(growable: false),
    );
    return ref.read(secureStoreProvider).writeString(_storageKey, payload);
  }

  Future<void> _recordTimelineEvent({
    required TimelineEventType type,
    required String title,
    required String detail,
    DateTime? dueAt,
    TimelineEventStatus status = TimelineEventStatus.info,
    String? relatedId,
  }) {
    final DateTime now = DateTime.now();
    return ref
        .read(timelineActionsProvider)
        .addMirroredEvent(
          TimelineEventEntity(
            id: 'timeline-milestone-${now.microsecondsSinceEpoch}',
            type: type,
            title: title,
            detail: detail,
            timestamp: now,
            dueAt: dueAt,
            status: status,
            phase: 'milestone',
            relatedId: relatedId,
          ),
        );
  }

  Future<void> _refreshCoachDecision() async {
    try {
      await ref.read(generateSiDecisionUseCaseProvider).call();
      ref.invalidate(domainSiDecisionProvider);
    } catch (_) {
      // Keep milestone updates resilient if SI decision refresh fails.
    }
  }
}
