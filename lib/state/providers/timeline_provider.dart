import 'package:fantastic_guacamole/core/eventing/domain_event.dart';
import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/state/controllers/profile_controller.dart';
import 'package:fantastic_guacamole/state/core/app_providers.dart';
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
