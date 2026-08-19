import 'package:fantastic_guacamole/core/eventing/domain_event.dart';
import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/state/controllers/profile_controller.dart';
import 'package:fantastic_guacamole/state/core/app_providers.dart'
    show soundEnabledProvider;
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/event_bus_provider.dart';
import 'package:fantastic_guacamole/system/audio/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final timelineActionsProvider = Provider<TimelineActions>((Ref ref) {
  return TimelineActions(ref);
});

final timelineProvider =
    NotifierProvider<TimelineNotifier, List<TimelineEventEntity>>(
      TimelineNotifier.new,
    );

final timelineOverdueProvider = Provider<List<TimelineEventEntity>>((Ref ref) {
  return ref
      .watch(timelineProvider)
      .where((TimelineEventEntity event) => event.isOverdue)
      .toList(growable: false);
});

final timelineUpcomingProvider = Provider<List<TimelineEventEntity>>((Ref ref) {
  return ref
      .watch(timelineProvider)
      .where((TimelineEventEntity event) => event.isUpcoming)
      .toList(growable: false);
});

final timelineRiskEventsProvider = Provider<List<TimelineEventEntity>>((
  Ref ref,
) {
  return ref
      .watch(timelineProvider)
      .where((TimelineEventEntity event) => event.isRisk)
      .toList(growable: false);
});

final timelineRecommendationsProvider = Provider<List<TimelineEventEntity>>((
  Ref ref,
) {
  return ref
      .watch(timelineProvider)
      .where((TimelineEventEntity event) => event.isRecommendation)
      .toList(growable: false);
});

final timelineHealthScoreProvider = Provider<int>((Ref ref) {
  final List<TimelineEventEntity> events = ref.watch(timelineProvider);
  final int overdue = events
      .where((TimelineEventEntity event) => event.isOverdue)
      .length;
  final int risks = events
      .where((TimelineEventEntity event) => event.isRisk)
      .length;
  final int milestones = events
      .where((TimelineEventEntity event) => event.isMilestone)
      .length;
  final int upcoming = events
      .where((TimelineEventEntity event) => event.isUpcoming)
      .length;
  final int penalty = (overdue * 12) + (risks * 10) + (upcoming > 8 ? 8 : 0);
  final int bonus = (milestones * 3).clamp(0, 18);
  return (100 - penalty + bonus).clamp(0, 100);
});

final timelineRiskScoreProvider = Provider<int>((Ref ref) {
  final int health = ref.watch(timelineHealthScoreProvider);
  return 100 - health;
});

class TimelineActions {
  const TimelineActions(this._ref);

  final Ref _ref;

  Future<void> addEvent({
    required TimelineEventEntity event,
    bool awardProgression = false,
  }) {
    return _ref
        .read(timelineProvider.notifier)
        .record(event, awardProgression: awardProgression);
  }

  Future<void> addMirroredEvent(TimelineEventEntity event) {
    return _ref
        .read(timelineProvider.notifier)
        .record(event, refreshPlanner: false, awardProgression: false);
  }

  List<TimelineEventEntity> eventsInRange({
    required DateTime start,
    required DateTime end,
  }) {
    return _ref
        .read(queryTimelineRangeUseCaseProvider)
        .call(start: start, end: end);
  }

  Future<void> schedule(TimelineEventEntity event) {
    return _ref.read(timelineProvider.notifier).schedule(event);
  }

  Future<void> reschedule(String id, DateTime dueAt) {
    return _ref.read(timelineProvider.notifier).reschedule(id, dueAt);
  }

  Future<void> complete(String id) {
    return _ref.read(timelineProvider.notifier).complete(id);
  }

  Future<void> skip(String id) {
    return _ref.read(timelineProvider.notifier).skip(id);
  }

  Future<void> recover(String id, DateTime dueAt) {
    return _ref.read(timelineProvider.notifier).recover(id, dueAt);
  }
}

class TimelineNotifier extends Notifier<List<TimelineEventEntity>> {
  static const _maxEvents = 500;

  @override
  List<TimelineEventEntity> build() {
    return ref.read(getTimelineEventsUseCaseProvider).call();
  }

  Future<void> record(
    TimelineEventEntity event, {
    bool refreshPlanner = true,
    bool awardProgression = false,
  }) async {
    await ref.read(addTimelineEventUseCaseProvider).call(event);
    final bool isMilestoneEvent =
        event.isLevelUp || event.isGoalComplete || event.isStreak;
    if (isMilestoneEvent) {
      final bool soundEnabled = ref.read(soundEnabledProvider);
      await AudioService.playMilestone(soundEnabled);
    }
    final updated = [event, ...state];
    state = updated.length > _maxEvents
        ? updated.sublist(0, _maxEvents)
        : updated;

    if (awardProgression) {
      await ref
          .read(profileProvider.notifier)
          .awardXP(10, source: 'timeline_event');
    }
    if (refreshPlanner) {
      await _refreshPlannerDecision();
    }
    ref
        .read(eventBusProvider)
        .emit(
          TimelineLifecycleEvent(
            eventId: event.id,
            title: event.title,
            type: event.type.name,
          ),
        );
  }

  Future<void> remove(String id) async {
    await ref.read(removeTimelineEventUseCaseProvider).call(id);
    state = state.where((event) => event.id != id).toList(growable: false);
  }

  Future<void> schedule(TimelineEventEntity event) async {
    final TimelineEventEntity scheduled = await ref
        .read(scheduleTimelineEventUseCaseProvider)
        .call(event);
    state = <TimelineEventEntity>[scheduled, ...state];
    await _afterLifecycleMutation(scheduled);
  }

  Future<void> reschedule(String id, DateTime dueAt) async {
    final TimelineEventEntity? updated = await ref
        .read(rescheduleTimelineEventUseCaseProvider)
        .call(id: id, dueAt: dueAt);
    if (updated != null) await _replaceAfterLifecycleMutation(updated);
  }

  Future<void> complete(String id) async {
    final TimelineEventEntity? updated = await ref
        .read(completeTimelineEventUseCaseProvider)
        .call(id);
    if (updated != null) await _replaceAfterLifecycleMutation(updated);
  }

  Future<void> skip(String id) async {
    final TimelineEventEntity? updated = await ref
        .read(skipTimelineEventUseCaseProvider)
        .call(id);
    if (updated != null) await _replaceAfterLifecycleMutation(updated);
  }

  Future<void> recover(String id, DateTime dueAt) async {
    final TimelineEventEntity? updated = await ref
        .read(recoverTimelineEventUseCaseProvider)
        .call(id: id, dueAt: dueAt);
    if (updated != null) await _replaceAfterLifecycleMutation(updated);
  }

  Future<void> _replaceAfterLifecycleMutation(
    TimelineEventEntity updated,
  ) async {
    state = <TimelineEventEntity>[
      for (final TimelineEventEntity event in state)
        if (event.id == updated.id) updated else event,
    ];
    await _afterLifecycleMutation(updated);
  }

  Future<void> _afterLifecycleMutation(TimelineEventEntity event) async {
    await _refreshPlannerDecision();
    ref
        .read(eventBusProvider)
        .emit(
          TimelineLifecycleEvent(
            eventId: event.id,
            title: event.title,
            type: event.type.name,
          ),
        );
  }

  Future<void> _refreshPlannerDecision() async {
    try {
      await ref.read(generateSiDecisionUseCaseProvider).call();
      ref.invalidate(domainSiDecisionProvider);
    } catch (_) {
      // Avoid blocking timeline writes if planner refresh fails.
    }
  }
}
