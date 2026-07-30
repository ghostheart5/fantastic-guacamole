import 'package:fantastic_guacamole/data/di/repositories_providers.dart';
import 'package:fantastic_guacamole/features/auth/domain/usecases/misc/add_emotion_to_timeline_usecase.dart';
import 'package:fantastic_guacamole/features/auth/domain/usecases/misc/add_goal_to_timeline_usecase.dart';
import 'package:fantastic_guacamole/features/auth/domain/usecases/misc/add_journal_to_timeline_usecase.dart';
import 'package:fantastic_guacamole/features/auth/domain/usecases/misc/add_memory_to_timeline_usecase.dart';
import 'package:fantastic_guacamole/features/auth/domain/usecases/misc/add_milestone_to_timeline_usecase.dart';
import 'package:fantastic_guacamole/features/auth/domain/usecases/misc/compare_timelines_usecase.dart';
import 'package:fantastic_guacamole/features/auth/domain/usecases/misc/export_timeline_usecase.dart';
import 'package:fantastic_guacamole/features/auth/domain/usecases/misc/generate_timeline_insights_usecase.dart';
import 'package:fantastic_guacamole/features/auth/domain/usecases/misc/generate_timeline_summary_usecase.dart';
import 'package:fantastic_guacamole/features/auth/domain/usecases/misc/remove_item_from_timeline_usecase.dart';
import 'package:fantastic_guacamole/features/auth/domain/usecases/misc/share_timeline_usecase.dart';
import 'package:fantastic_guacamole/features/auth/domain/usecases/misc/connect_timeline_to_goals_usecase.dart';
import 'package:fantastic_guacamole/features/auth/domain/usecases/misc/connect_timeline_to_habits_usecase.dart';
import 'package:fantastic_guacamole/features/auth/domain/usecases/misc/connect_timeline_to_projects_usecase.dart';
import 'package:fantastic_guacamole/features/auth/domain/usecases/misc/connect_timeline_to_tasks_usecase.dart';
import 'package:fantastic_guacamole/features/auth/domain/usecases/misc/create_timeline_event_usecase.dart';
import 'package:fantastic_guacamole/features/auth/domain/usecases/misc/detect_timeline_conflict_usecase.dart';
import 'package:fantastic_guacamole/features/auth/domain/usecases/misc/detect_timeline_risk_usecase.dart';
import 'package:fantastic_guacamole/features/auth/domain/usecases/misc/forecast_timeline_outcomes_usecase.dart';
import 'package:fantastic_guacamole/features/auth/domain/usecases/misc/prioritize_timeline_items_usecase.dart';
import 'package:fantastic_guacamole/features/auth/domain/usecases/misc/suggest_timeline_adjustments_usecase.dart';
import 'package:fantastic_guacamole/features/auth/domain/usecases/misc/surface_timeline_warnings_usecase.dart';
import 'package:fantastic_guacamole/features/auth/domain/usecases/misc/delete_timeline_event_usecase.dart';
import 'package:fantastic_guacamole/features/auth/domain/usecases/misc/show_due_next_timeline_usecase.dart';
import 'package:fantastic_guacamole/features/auth/domain/usecases/misc/show_falling_behind_timeline_usecase.dart';
import 'package:fantastic_guacamole/features/auth/domain/usecases/misc/show_timeline_on_track_usecase.dart';
import 'package:fantastic_guacamole/features/auth/domain/usecases/misc/track_completed_events_usecase.dart';
import 'package:fantastic_guacamole/features/auth/domain/usecases/misc/track_deadlines_usecase.dart';
import 'package:fantastic_guacamole/features/auth/domain/usecases/misc/update_timeline_event_usecase.dart';
import 'package:fantastic_guacamole/features/auth/domain/usecases/misc/view_daily_timeline_usecase.dart';
import 'package:fantastic_guacamole/features/auth/domain/usecases/misc/view_life_journey_usecase.dart';
import 'package:fantastic_guacamole/features/auth/domain/usecases/misc/view_monthly_timeline_usecase.dart';
import 'package:fantastic_guacamole/features/auth/domain/usecases/misc/view_timeline_activity_usecase.dart';
import 'package:fantastic_guacamole/features/auth/domain/usecases/misc/view_timeline_event_usecase.dart';
import 'package:fantastic_guacamole/features/auth/domain/usecases/misc/view_timeline_usecase.dart';
import 'package:fantastic_guacamole/features/auth/domain/usecases/misc/view_weekly_timeline_usecase.dart';
import 'package:fantastic_guacamole/features/auth/domain/usecases/misc/view_yearly_timeline_usecase.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final createTimelineEventUsecaseProvider = Provider<CreateTimelineEventUsecase>(
  (Ref ref) {
    return CreateTimelineEventUsecase(ref.read(timelineRepositoryProvider));
  },
);

final viewTimelineUsecaseProvider = Provider<ViewTimelineUsecase>((Ref ref) {
  return ViewTimelineUsecase(ref.read(timelineRepositoryProvider));
});

final deleteTimelineEventUsecaseProvider = Provider<DeleteTimelineEventUsecase>(
  (Ref ref) {
    return DeleteTimelineEventUsecase(ref.read(timelineRepositoryProvider));
  },
);

final updateTimelineEventUsecaseProvider = Provider<UpdateTimelineEventUsecase>(
  (Ref ref) {
    return UpdateTimelineEventUsecase(ref.read(timelineRepositoryProvider));
  },
);

final addEmotionToTimelineUsecaseProvider =
    Provider<AddEmotionToTimelineUsecase>((Ref ref) {
      return AddEmotionToTimelineUsecase(ref.read(timelineRepositoryProvider));
    });

final addGoalToTimelineUsecaseProvider = Provider<AddGoalToTimelineUsecase>((
  Ref ref,
) {
  return AddGoalToTimelineUsecase(ref.read(timelineRepositoryProvider));
});

final addJournalToTimelineUsecaseProvider =
    Provider<AddJournalToTimelineUsecase>((Ref ref) {
      return AddJournalToTimelineUsecase(ref.read(timelineRepositoryProvider));
    });

final addMemoryToTimelineUsecaseProvider = Provider<AddMemoryToTimelineUsecase>(
  (Ref ref) {
    return AddMemoryToTimelineUsecase(ref.read(timelineRepositoryProvider));
  },
);

final addMilestoneToTimelineUsecaseProvider =
    Provider<AddMilestoneToTimelineUsecase>((Ref ref) {
      return AddMilestoneToTimelineUsecase(
        ref.read(timelineRepositoryProvider),
      );
    });

final viewDailyTimelineUsecaseProvider = Provider<ViewDailyTimelineUsecase>((
  Ref ref,
) {
  return ViewDailyTimelineUsecase(ref.read(timelineRepositoryProvider));
});

final viewWeeklyTimelineUsecaseProvider = Provider<ViewWeeklyTimelineUsecase>((
  Ref ref,
) {
  return ViewWeeklyTimelineUsecase(ref.read(timelineRepositoryProvider));
});

final viewMonthlyTimelineUsecaseProvider = Provider<ViewMonthlyTimelineUsecase>(
  (Ref ref) {
    return ViewMonthlyTimelineUsecase(ref.read(timelineRepositoryProvider));
  },
);

final viewYearlyTimelineUsecaseProvider = Provider<ViewYearlyTimelineUsecase>((
  Ref ref,
) {
  return ViewYearlyTimelineUsecase(ref.read(timelineRepositoryProvider));
});

final viewTimelineEventUsecaseProvider = Provider<ViewTimelineEventUsecase>((
  Ref ref,
) {
  return ViewTimelineEventUsecase(ref.read(timelineRepositoryProvider));
});

final viewTimelineActivityUsecaseProvider =
    Provider<ViewTimelineActivityUsecase>((Ref ref) {
      return ViewTimelineActivityUsecase(ref.read(timelineRepositoryProvider));
    });

final viewLifeJourneyUsecaseProvider = Provider<ViewLifeJourneyUsecase>((
  Ref ref,
) {
  return ViewLifeJourneyUsecase(ref.read(timelineRepositoryProvider));
});

final compareTimelinesUsecaseProvider = Provider<CompareTimelinesUsecase>((
  Ref ref,
) {
  return const CompareTimelinesUsecase();
});

final generateTimelineSummaryUsecaseProvider =
    Provider<GenerateTimelineSummaryUsecase>((Ref ref) {
      return GenerateTimelineSummaryUsecase(
        ref.read(timelineRepositoryProvider),
      );
    });

final generateTimelineInsightsUsecaseProvider =
    Provider<GenerateTimelineInsightsUsecase>((Ref ref) {
      return GenerateTimelineInsightsUsecase(
        ref.read(timelineRepositoryProvider),
      );
    });

final exportTimelineUsecaseProvider = Provider<ExportTimelineUsecase>((
  Ref ref,
) {
  return ExportTimelineUsecase(ref.read(timelineRepositoryProvider));
});

final shareTimelineUsecaseProvider = Provider<ShareTimelineUsecase>((Ref ref) {
  return ShareTimelineUsecase(ref.read(timelineRepositoryProvider));
});

final removeItemFromTimelineUsecaseProvider =
    Provider<RemoveItemFromTimelineUsecase>((Ref ref) {
      return RemoveItemFromTimelineUsecase(
        ref.read(timelineRepositoryProvider),
      );
    });

final trackDeadlinesUsecaseProvider = Provider<TrackDeadlinesUsecase>((
  Ref ref,
) {
  return TrackDeadlinesUsecase(ref.read(timelineRepositoryProvider));
});

final trackCompletedEventsUsecaseProvider =
    Provider<TrackCompletedEventsUsecase>((Ref ref) {
      return TrackCompletedEventsUsecase(ref.read(timelineRepositoryProvider));
    });

final showDueNextTimelineUsecaseProvider = Provider<ShowDueNextTimelineUsecase>(
  (Ref ref) {
    return ShowDueNextTimelineUsecase(ref.read(timelineRepositoryProvider));
  },
);

final showFallingBehindTimelineUsecaseProvider =
    Provider<ShowFallingBehindTimelineUsecase>((Ref ref) {
      return ShowFallingBehindTimelineUsecase(
        ref.read(timelineRepositoryProvider),
      );
    });

final showTimelineOnTrackUsecaseProvider = Provider<ShowTimelineOnTrackUsecase>(
  (Ref ref) {
    return ShowTimelineOnTrackUsecase(ref.read(timelineRepositoryProvider));
  },
);

final detectTimelineRiskUsecaseProvider = Provider<DetectTimelineRiskUsecase>((
  Ref ref,
) {
  return DetectTimelineRiskUsecase(ref.read(timelineRepositoryProvider));
});

final detectTimelineConflictUsecaseProvider =
    Provider<DetectTimelineConflictUsecase>((Ref ref) {
      return DetectTimelineConflictUsecase(
        ref.read(timelineRepositoryProvider),
      );
    });

final forecastTimelineOutcomesUsecaseProvider =
    Provider<ForecastTimelineOutcomesUsecase>((Ref ref) {
      return ForecastTimelineOutcomesUsecase(
        ref.read(timelineRepositoryProvider),
      );
    });

final prioritizeTimelineItemsUsecaseProvider =
    Provider<PrioritizeTimelineItemsUsecase>((Ref ref) {
      return PrioritizeTimelineItemsUsecase(
        ref.read(timelineRepositoryProvider),
      );
    });

final surfaceTimelineWarningsUsecaseProvider =
    Provider<SurfaceTimelineWarningsUsecase>((Ref ref) {
      return SurfaceTimelineWarningsUsecase(
        ref.read(timelineRepositoryProvider),
      );
    });

final suggestTimelineAdjustmentsUsecaseProvider =
    Provider<SuggestTimelineAdjustmentsUsecase>((Ref ref) {
      return SuggestTimelineAdjustmentsUsecase(
        ref.read(timelineRepositoryProvider),
      );
    });

final connectTimelineToGoalsUsecaseProvider =
    Provider<ConnectTimelineToGoalsUsecase>((Ref ref) {
      return ConnectTimelineToGoalsUsecase(
        ref.read(timelineRepositoryProvider),
      );
    });

final connectTimelineToTasksUsecaseProvider =
    Provider<ConnectTimelineToTasksUsecase>((Ref ref) {
      return ConnectTimelineToTasksUsecase(
        ref.read(timelineRepositoryProvider),
      );
    });

final connectTimelineToProjectsUsecaseProvider =
    Provider<ConnectTimelineToProjectsUsecase>((Ref ref) {
      return ConnectTimelineToProjectsUsecase(
        ref.read(timelineRepositoryProvider),
      );
    });

final connectTimelineToHabitsUsecaseProvider =
    Provider<ConnectTimelineToHabitsUsecase>((Ref ref) {
      return ConnectTimelineToHabitsUsecase(
        ref.read(timelineRepositoryProvider),
      );
    });
