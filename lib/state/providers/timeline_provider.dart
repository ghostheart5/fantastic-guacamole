import 'package:fantastic_guacamole/core/eventing/domain_event.dart';
import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/state/controllers/profile_controller.dart';
import 'package:fantastic_guacamole/state/core/app_providers.dart'
    show soundEnabledProvider;
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/event_bus_provider.dart';
import 'package:fantastic_guacamole/state/providers/feature_derived_providers.dart';
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
        .record(
          event,
          refreshCoach: false,
          syncSoulMap: false,
          awardProgression: false,
        );
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
    bool refreshCoach = true,
    bool syncSoulMap = true,
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

    if (syncSoulMap) {
      ref.invalidate(soulStateProvider);
    }
    if (awardProgression) {
      ref.read(profileProvider.notifier).addXP(10);
    }
    if (refreshCoach) {
      await _refreshCoachDecision();
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

  Future<void> _refreshCoachDecision() async {
    try {
      await ref.read(generateSiDecisionUseCaseProvider).call();
      ref.invalidate(domainSiDecisionProvider);
    } catch (_) {
      // Avoid blocking timeline writes if coach refresh fails.
    }
  }
}
