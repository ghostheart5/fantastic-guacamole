import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/domain/entities/project_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/features/auth/domain/usecases/misc/detect_timeline_conflict_usecase.dart';
import 'package:fantastic_guacamole/features/auth/domain/usecases/misc/detect_timeline_risk_usecase.dart';
import 'package:fantastic_guacamole/features/auth/domain/usecases/misc/forecast_timeline_outcomes_usecase.dart';
import 'package:fantastic_guacamole/features/auth/domain/usecases/misc/suggest_timeline_adjustments_usecase.dart';
import 'package:fantastic_guacamole/features/auth/domain/usecases/misc/surface_timeline_warnings_usecase.dart';
import 'package:fantastic_guacamole/core/eventing/domain_event.dart';
import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/state/controllers/profile_controller.dart';
import 'package:fantastic_guacamole/state/core/app_providers.dart'
    show soundEnabledProvider;
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/event_bus_provider.dart';
import 'package:fantastic_guacamole/state/providers/feature_derived_providers.dart';
import 'package:fantastic_guacamole/state/providers/timeline_misc_usecase_providers.dart';
import 'package:fantastic_guacamole/system/audio/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final timelineActionsProvider = Provider<TimelineActions>((Ref ref) {
  return TimelineActions(ref);
});

final timelineProvider =
    NotifierProvider<TimelineNotifier, List<TimelineEventEntity>>(
      TimelineNotifier.new,
    );

final timelineTodayProvider = Provider<List<TimelineEventEntity>>((Ref ref) {
  ref.watch(timelineProvider);
  return ref.read(viewDailyTimelineUsecaseProvider).call(DateTime.now());
});

final timelineThisWeekProvider = Provider<List<TimelineEventEntity>>((Ref ref) {
  ref.watch(timelineProvider);
  return ref.read(viewWeeklyTimelineUsecaseProvider).call(DateTime.now());
});

final timelineThisMonthProvider = Provider<List<TimelineEventEntity>>((
  Ref ref,
) {
  ref.watch(timelineProvider);
  return ref.read(viewMonthlyTimelineUsecaseProvider).call(DateTime.now());
});

final timelineThisYearProvider = Provider<List<TimelineEventEntity>>((Ref ref) {
  ref.watch(timelineProvider);
  return ref.read(viewYearlyTimelineUsecaseProvider).call(DateTime.now());
});

final timelineActivityProvider = Provider<List<TimelineEventEntity>>((Ref ref) {
  ref.watch(timelineProvider);
  return ref.read(viewTimelineActivityUsecaseProvider).call();
});

final timelineLifeJourneyProvider = Provider<List<TimelineEventEntity>>((
  Ref ref,
) {
  ref.watch(timelineProvider);
  return ref.read(viewLifeJourneyUsecaseProvider).call();
});

final timelineEventByIdProvider = Provider.family<TimelineEventEntity?, String>(
  (Ref ref, String id) {
    ref.watch(timelineProvider);
    return ref.read(viewTimelineEventUsecaseProvider).call(id);
  },
);
final timelineDeadlinesProvider = Provider<List<TimelineEventEntity>>((
  Ref ref,
) {
  ref.watch(timelineProvider);
  return ref.read(trackDeadlinesUsecaseProvider).call();
});

final timelineCompletedEventsProvider = Provider<List<TimelineEventEntity>>((
  Ref ref,
) {
  ref.watch(timelineProvider);
  return ref.read(trackCompletedEventsUsecaseProvider).call();
});

final timelineDueNextProvider = Provider<List<TimelineEventEntity>>((Ref ref) {
  ref.watch(timelineProvider);
  return ref.read(showDueNextTimelineUsecaseProvider).call();
});

final timelineFallingBehindProvider = Provider<List<TimelineEventEntity>>((
  Ref ref,
) {
  ref.watch(timelineProvider);
  return ref.read(showFallingBehindTimelineUsecaseProvider).call();
});

final timelineOnTrackResultProvider = Provider((Ref ref) {
  ref.watch(timelineProvider);
  return ref.read(showTimelineOnTrackUsecaseProvider).call();
});
final timelineRiskResultProvider = Provider<TimelineRiskResult>((Ref ref) {
  ref.watch(timelineProvider);
  return ref.read(detectTimelineRiskUsecaseProvider).call();
});

final timelineConflictProvider = Provider<List<TimelineConflict>>((Ref ref) {
  ref.watch(timelineProvider);
  return ref.read(detectTimelineConflictUsecaseProvider).call();
});

final timelineForecastProvider = Provider<List<TimelineForecastResult>>((
  Ref ref,
) {
  ref.watch(timelineProvider);
  return ref.read(forecastTimelineOutcomesUsecaseProvider).call();
});

final timelinePrioritizedItemsProvider = Provider<List<TimelineEventEntity>>((
  Ref ref,
) {
  ref.watch(timelineProvider);
  return ref.read(prioritizeTimelineItemsUsecaseProvider).call();
});

final timelineWarningsProvider = Provider<List<TimelineWarning>>((Ref ref) {
  ref.watch(timelineProvider);
  return ref.read(surfaceTimelineWarningsUsecaseProvider).call();
});

final timelineAdjustmentsProvider = Provider<List<TimelineAdjustment>>((
  Ref ref,
) {
  ref.watch(timelineProvider);
  return ref.read(suggestTimelineAdjustmentsUsecaseProvider).call();
});
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

  Future<void> addEmotion({
    required String title,
    required String detail,
    String? relatedId,
    DateTime? timestamp,
  }) async {
    await _ref
        .read(addEmotionToTimelineUsecaseProvider)
        .call(
          title: title,
          detail: detail,
          relatedId: relatedId,
          timestamp: timestamp,
        );
    _ref.invalidate(timelineProvider);
  }

  Future<void> addGoal({
    required String title,
    required String detail,
    String? relatedId,
    DateTime? timestamp,
    DateTime? dueAt,
  }) async {
    await _ref
        .read(addGoalToTimelineUsecaseProvider)
        .call(
          title: title,
          detail: detail,
          relatedId: relatedId,
          timestamp: timestamp,
          dueAt: dueAt,
        );
    _ref.invalidate(timelineProvider);
  }

  Future<void> addJournal({
    required String title,
    required String detail,
    String? relatedId,
    DateTime? timestamp,
  }) async {
    await _ref
        .read(addJournalToTimelineUsecaseProvider)
        .call(
          title: title,
          detail: detail,
          relatedId: relatedId,
          timestamp: timestamp,
        );
    _ref.invalidate(timelineProvider);
  }

  Future<void> addMemory({
    required String title,
    required String detail,
    String? relatedId,
    DateTime? timestamp,
  }) async {
    await _ref
        .read(addMemoryToTimelineUsecaseProvider)
        .call(
          title: title,
          detail: detail,
          relatedId: relatedId,
          timestamp: timestamp,
        );
    _ref.invalidate(timelineProvider);
  }

  Future<void> addMilestone({
    required String title,
    required String detail,
    String? relatedId,
    DateTime? timestamp,
  }) async {
    await _ref
        .read(addMilestoneToTimelineUsecaseProvider)
        .call(
          title: title,
          detail: detail,
          relatedId: relatedId,
          timestamp: timestamp,
        );
    _ref.invalidate(timelineProvider);
  }

  List<TimelineEventEntity> viewTimeline() {
    return _ref.read(viewTimelineUsecaseProvider).call();
  }

  List<TimelineEventEntity> viewDaily(DateTime day) {
    return _ref.read(viewDailyTimelineUsecaseProvider).call(day);
  }

  List<TimelineEventEntity> viewWeekly(DateTime day) {
    return _ref.read(viewWeeklyTimelineUsecaseProvider).call(day);
  }

  List<TimelineEventEntity> viewMonthly(DateTime month) {
    return _ref.read(viewMonthlyTimelineUsecaseProvider).call(month);
  }

  List<TimelineEventEntity> viewYearly(DateTime year) {
    return _ref.read(viewYearlyTimelineUsecaseProvider).call(year);
  }

  TimelineEventEntity? viewEvent(String id) {
    return _ref.read(viewTimelineEventUsecaseProvider).call(id);
  }

  List<TimelineEventEntity> viewActivity({int limit = 50}) {
    return _ref.read(viewTimelineActivityUsecaseProvider).call(limit: limit);
  }

  List<TimelineEventEntity> viewLifeJourney() {
    return _ref.read(viewLifeJourneyUsecaseProvider).call();
  }

  TimelineRiskResult detectRisk() {
    return _ref.read(detectTimelineRiskUsecaseProvider).call();
  }

  List<TimelineConflict> detectConflicts() {
    return _ref.read(detectTimelineConflictUsecaseProvider).call();
  }

  List<TimelineForecastResult> forecastOutcomes() {
    return _ref.read(forecastTimelineOutcomesUsecaseProvider).call();
  }

  List<TimelineEventEntity> prioritizeItems({int limit = 10}) {
    return _ref.read(prioritizeTimelineItemsUsecaseProvider).call(limit: limit);
  }

  List<TimelineWarning> surfaceWarnings() {
    return _ref.read(surfaceTimelineWarningsUsecaseProvider).call();
  }

  List<TimelineAdjustment> suggestAdjustments() {
    return _ref.read(suggestTimelineAdjustmentsUsecaseProvider).call();
  }

  Future<void> connectGoal(GoalEntity goal) async {
    await _ref.read(connectTimelineToGoalsUsecaseProvider).call(goal);
    _ref.invalidate(timelineProvider);
  }

  Future<void> connectHabit(HabitEntity habit) async {
    await _ref.read(connectTimelineToHabitsUsecaseProvider).call(habit);
    _ref.invalidate(timelineProvider);
  }

  Future<void> connectProject(ProjectEntity project) async {
    await _ref.read(connectTimelineToProjectsUsecaseProvider).call(project);
    _ref.invalidate(timelineProvider);
  }

  Future<void> connectTask(TaskEntity task) async {
    await _ref.read(connectTimelineToTasksUsecaseProvider).call(task);
    _ref.invalidate(timelineProvider);
  }
}

class TimelineNotifier extends Notifier<List<TimelineEventEntity>> {
  static const _maxEvents = 500;

  @override
  List<TimelineEventEntity> build() {
    return ref.read(viewTimelineUsecaseProvider).call();
  }

  Future<void> record(
    TimelineEventEntity event, {
    bool refreshCoach = true,
    bool syncSoulMap = true,
    bool awardProgression = false,
  }) async {
    await ref.read(createTimelineEventUsecaseProvider).call(event);
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
    await ref.read(deleteTimelineEventUsecaseProvider).call(id);
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
