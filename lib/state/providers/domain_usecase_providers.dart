import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/core/archive_goal_usecase.dart'
    as feature_goal_archive;
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/core/favorite_goal_usecase.dart'
    as feature_goal_favorite;
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/core/pin_goal_usecase.dart'
    as feature_goal_pin;
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/core/restore_goal_usecase.dart'
    as feature_goal_restore_metadata;
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/core/unfavorite_goal_usecase.dart'
    as feature_goal_unfavorite;
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/core/unpin_goal_usecase.dart'
    as feature_goal_unpin;
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/links/link_emotion_to_goal_usecase.dart'
    as feature_goal_link_emotion;
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/links/link_focus_session_to_goal_usecase.dart'
    as feature_goal_link_focus;
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/links/link_habit_to_goal_usecase.dart'
    as feature_goal_link_habit;
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/links/link_journal_entry_to_goal_usecase.dart'
    as feature_goal_link_journal;
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/links/unlink_emotion_from_goal_usecase.dart'
    as feature_goal_unlink_emotion;
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/links/unlink_focus_session_from_goal_usecase.dart'
    as feature_goal_unlink_focus;
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/links/unlink_habit_from_goal_usecase.dart'
    as feature_goal_unlink_habit;
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/links/unlink_journal_entry_from_goal_usecase.dart'
    as feature_goal_unlink_journal;
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/portability/backup_goals_usecase.dart'
    as feature_goal_backup;
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/portability/export_goals_usecase.dart'
    as feature_goal_export;
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/portability/import_goals_usecase.dart'
    as feature_goal_import;
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/portability/restore_goals_usecase.dart'
    as feature_goal_restore;
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/config/create_goal_category_usecase.dart'
    as feature_goal_category_create;
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/config/delete_goal_category_usecase.dart'
    as feature_goal_category_delete;
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/config/set_goal_priority_usecase.dart'
    as feature_goal_priority_set;
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/config/update_goal_category_usecase.dart'
    as feature_goal_category_update;
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/config/update_goal_priority_usecase.dart'
    as feature_goal_priority_update;
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/templates/create_goal_from_template_usecase.dart'
    as feature_goal_from_template;
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/templates/save_goal_as_template_usecase.dart'
    as feature_goal_save_template;
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/templates/update_goal_template_usecase.dart'
    as feature_goal_update_template;
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/rewards/award_goal_achievement_usecase.dart'
    as feature_goal_award;
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/rewards/celebrate_goal_completion_usecase.dart'
    as feature_goal_celebrate;
import 'package:fantastic_guacamole/state/providers/service_providers.dart';
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/reminders/create_goal_reminder_usecase.dart'
    as feature_goal_create_reminder;
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/reminders/delete_goal_reminder_usecase.dart'
    as feature_goal_delete_reminder;
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/reminders/dismiss_goal_reminder_usecase.dart'
    as feature_goal_dismiss_reminder;
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/reminders/snooze_goal_reminder_usecase.dart'
    as feature_goal_snooze_reminder;
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/reminders/update_goal_reminder_usecase.dart'
    as feature_goal_update_reminder;
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/links/link_task_to_goal_usecase.dart'
    as feature_goal_link_task;
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/links/unlink_task_from_goal_usecase.dart'
    as feature_goal_unlink_task;
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/lifecycle/abandon_goal_usecase.dart'
    as feature_goal_abandon;
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/lifecycle/complete_goal_usecase.dart'
    as feature_goal_lifecycle_complete;
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/lifecycle/mark_goal_completed_usecase.dart'
    as feature_goal_mark_completed;
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/lifecycle/mark_goal_failed_usecase.dart'
    as feature_goal_mark_failed;
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/lifecycle/mark_goal_in_progress_usecase.dart'
    as feature_goal_mark_in_progress;
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/lifecycle/pause_goal_usecase.dart'
    as feature_goal_pause;
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/lifecycle/reopen_goal_usecase.dart'
    as feature_goal_reopen;
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/lifecycle/resume_goal_usecase.dart'
    as feature_goal_resume;
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/lifecycle/start_goal_usecase.dart'
    as feature_goal_start;
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/config/remove_goal_deadline_usecase.dart'
    as feature_goal_remove_deadline;
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/config/set_goal_deadline_usecase.dart'
    as feature_goal_set_deadline;
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/config/update_goal_deadline_usecase.dart'
    as feature_goal_update_deadline;
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/insights/generate_goal_breakdown_usecase.dart'
    as feature_goal_breakdown;
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/insights/generate_goal_insights_usecase.dart'
    as feature_goal_insights;
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/insights/generate_goal_plan_usecase.dart'
    as feature_goal_plan;
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/insights/generate_goal_recommendations_usecase.dart'
    as feature_goal_recommendations;
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/insights/generate_goal_summary_usecase.dart'
    as feature_goal_summary;
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/insights/recommend_goals_usecase.dart'
    as feature_goal_recommend_goals;
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/insights/recommend_next_action_usecase.dart'
    as feature_goal_next_action;
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/analytics/detect_goal_conflicts_usecase.dart'
    as feature_goal_conflicts;
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/analytics/detect_goal_risk_usecase.dart'
    as feature_goal_risk;
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/analytics/detect_goal_stagnation_usecase.dart'
    as feature_goal_stagnation;
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/analytics/predict_goal_completion_usecase.dart'
    as feature_goal_completion_prediction;
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/analytics/predict_goal_success_usecase.dart'
    as feature_goal_success_prediction;
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/analytics/view_goal_analytics_usecase.dart'
    as feature_goal_analytics;
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/analytics/view_goal_completion_rate_usecase.dart'
    as feature_goal_completion_rate;
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/analytics/view_goal_streaks_usecase.dart'
    as feature_goal_streaks;
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/analytics/view_goal_trends_usecase.dart'
    as feature_goal_trends;
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/structure/complete_subgoal_usecase.dart'
    as feature_goal_complete_subgoal;
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/structure/create_subgoal_usecase.dart'
    as feature_goal_create_subgoal;
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/structure/delete_subgoal_usecase.dart'
    as feature_goal_delete_subgoal;
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/structure/update_subgoal_usecase.dart'
    as feature_goal_update_subgoal;
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/structure/complete_milestone_usecase.dart'
    as feature_goal_complete_milestone;
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/structure/create_milestone_usecase.dart'
    as feature_goal_create_milestone;
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/structure/delete_milestone_usecase.dart'
    as feature_goal_delete_milestone;
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/structure/reopen_milestone_usecase.dart'
    as feature_goal_reopen_milestone;
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/structure/update_milestone_usecase.dart'
    as feature_goal_update_milestone;
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/progress/calculate_goal_score_usecase.dart'
    as feature_goal_score;
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/progress/calculate_goal_success_rate_usecase.dart'
    as feature_goal_success_rate;
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/progress/decrement_goal_progress_usecase.dart'
    as feature_goal_progress_decrement;
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/progress/increment_goal_progress_usecase.dart'
    as feature_goal_progress_increment;
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/progress/reset_goal_progress_usecase.dart'
    as feature_goal_progress_reset;
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/progress/update_goal_progress_usecase.dart'
    as feature_goal_progress_update;
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/types/domain/create_career_goal_usecase.dart'
    as feature_goal_career;
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/types/domain/create_financial_goal_usecase.dart'
    as feature_goal_financial;
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/types/domain/create_fitness_goal_usecase.dart'
    as feature_goal_fitness;
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/types/domain/create_health_goal_usecase.dart'
    as feature_goal_health;
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/types/domain/create_learning_goal_usecase.dart'
    as feature_goal_learning;
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/types/domain/create_personal_goal_usecase.dart'
    as feature_goal_personal;
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/types/domain/create_productivity_goal_usecase.dart'
    as feature_goal_productivity;
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/types/domain/create_relationship_goal_usecase.dart'
    as feature_goal_relationship;
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/types/domain/create_spiritual_goal_usecase.dart'
    as feature_goal_spiritual;
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/types/style/create_lifetime_goal_usecase.dart'
    as feature_goal_lifetime;
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/types/style/create_micro_goal_usecase.dart'
    as feature_goal_micro;
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/types/style/create_smart_goal_usecase.dart'
    as feature_goal_smart;
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/types/style/create_stretch_goal_usecase.dart'
    as feature_goal_stretch;
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/types/timeframe/create_daily_goal_usecase.dart'
    as feature_goal_daily;
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/types/timeframe/create_weekly_goal_usecase.dart'
    as feature_goal_weekly;
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/types/timeframe/create_monthly_goal_usecase.dart'
    as feature_goal_monthly;
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/types/timeframe/create_yearly_goal_usecase.dart'
    as feature_goal_yearly;
import 'dart:convert';

import 'package:fantastic_guacamole/data/di/repositories_providers.dart';
import 'package:fantastic_guacamole/data/di/storage_providers.dart';
import 'package:fantastic_guacamole/domain/entities/extended_domain_entities.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/domain/entities/si_decision_entity.dart';
import 'package:fantastic_guacamole/domain/entities/si_state_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_extended_domain_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_goal_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_identity_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_insight_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_log_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_memory_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_notification_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_plan_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_profile_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_progression_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_project_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_routine_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_si_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_subtask_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_theme_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_timeline_repository.dart';
import 'package:fantastic_guacamole/domain/usecases/add_insight.dart';
import 'package:fantastic_guacamole/domain/usecases/add_log_entry.dart';
import 'package:fantastic_guacamole/domain/usecases/add_timeline_event.dart';
import 'package:fantastic_guacamole/domain/usecases/archive_goal.dart';
import 'package:fantastic_guacamole/domain/usecases/cancel_notification.dart';
import 'package:fantastic_guacamole/domain/usecases/complete_goal.dart';
import 'package:fantastic_guacamole/domain/usecases/complete_task.dart';
import 'package:fantastic_guacamole/domain/usecases/create_goal.dart';
import 'package:fantastic_guacamole/domain/usecases/create_plan.dart';
import 'package:fantastic_guacamole/domain/usecases/create_project.dart';
import 'package:fantastic_guacamole/domain/usecases/create_routine.dart';
import 'package:fantastic_guacamole/domain/usecases/create_subtask.dart';
import 'package:fantastic_guacamole/domain/usecases/create_task.dart';
import 'package:fantastic_guacamole/domain/usecases/delete_goal.dart';
import 'package:fantastic_guacamole/domain/usecases/delete_memory.dart';
import 'package:fantastic_guacamole/domain/usecases/delete_project.dart';
import 'package:fantastic_guacamole/domain/usecases/delete_routine.dart';
import 'package:fantastic_guacamole/domain/usecases/delete_subtask.dart';
import 'package:fantastic_guacamole/domain/usecases/delete_task.dart';
import 'package:fantastic_guacamole/domain/usecases/generate_insight_from_event.dart';
import 'package:fantastic_guacamole/domain/usecases/generate_si_decision.dart';
import 'package:fantastic_guacamole/domain/usecases/get_all_themes.dart';
import 'package:fantastic_guacamole/domain/usecases/get_analytics_metrics.dart';
import 'package:fantastic_guacamole/domain/usecases/get_coach_messages.dart';
import 'package:fantastic_guacamole/domain/usecases/get_current_theme.dart';
import 'package:fantastic_guacamole/domain/usecases/get_extended_app_settings.dart';
import 'package:fantastic_guacamole/domain/usecases/get_goals.dart';
import 'package:fantastic_guacamole/domain/usecases/get_identity_profile.dart';
import 'package:fantastic_guacamole/domain/usecases/get_insights.dart';
import 'package:fantastic_guacamole/domain/usecases/get_journal_entries.dart';
import 'package:fantastic_guacamole/domain/usecases/get_logs.dart';
import 'package:fantastic_guacamole/domain/usecases/get_memories.dart';
import 'package:fantastic_guacamole/domain/usecases/get_plan.dart';
import 'package:fantastic_guacamole/domain/usecases/get_profile.dart';
import 'package:fantastic_guacamole/domain/usecases/get_progression.dart';
import 'package:fantastic_guacamole/domain/usecases/get_projects.dart';
import 'package:fantastic_guacamole/domain/usecases/get_routines.dart';
import 'package:fantastic_guacamole/domain/usecases/get_si_queries_extended.dart';
import 'package:fantastic_guacamole/domain/usecases/get_subtasks.dart';
import 'package:fantastic_guacamole/domain/usecases/get_tasks.dart';
import 'package:fantastic_guacamole/domain/usecases/get_timeline_events.dart';
import 'package:fantastic_guacamole/domain/usecases/remove_timeline_event.dart';
import 'package:fantastic_guacamole/domain/usecases/reopen_goal.dart';
import 'package:fantastic_guacamole/domain/usecases/save_analytics_metric.dart';
import 'package:fantastic_guacamole/domain/usecases/save_coach_message.dart';
import 'package:fantastic_guacamole/domain/usecases/save_extended_app_setting.dart';
import 'package:fantastic_guacamole/domain/usecases/save_goals.dart';
import 'package:fantastic_guacamole/domain/usecases/save_identity_profile.dart';
import 'package:fantastic_guacamole/domain/usecases/save_journal_entry.dart';
import 'package:fantastic_guacamole/domain/usecases/save_memories.dart';
import 'package:fantastic_guacamole/domain/usecases/save_memory.dart';
import 'package:fantastic_guacamole/domain/usecases/save_projects.dart';
import 'package:fantastic_guacamole/domain/usecases/save_routines.dart';
import 'package:fantastic_guacamole/domain/usecases/save_si_query_extended.dart';
import 'package:fantastic_guacamole/domain/usecases/save_subtasks.dart';
import 'package:fantastic_guacamole/domain/usecases/save_theme.dart';
import 'package:fantastic_guacamole/domain/usecases/save_timeline_events.dart';
import 'package:fantastic_guacamole/domain/usecases/schedule_notification.dart';
import 'package:fantastic_guacamole/domain/usecases/switch_theme.dart';
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/view/view_active_goals_usecase.dart';
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/view/view_archived_goals_usecase.dart';
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/view/view_completed_goals_usecase.dart';
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/view/view_goal_activity_usecase.dart';
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/view/view_goal_details_usecase.dart';
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/view/view_goal_history_usecase.dart';
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/view/view_goal_timeline_usecase.dart';
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/core/create_goal_usecase.dart'
    as feature_goal_create;
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/core/delete_goal_usecase.dart'
    as feature_goal_delete;
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/core/duplicate_goal_usecase.dart'
    as feature_goal_duplicate;
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/core/update_goal_usecase.dart'
    as feature_goal_update;
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/view/view_goal_usecase.dart';
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/view/view_overdue_goals_usecase.dart';
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/core/filter_goals_usecase.dart'
    as feature_goal_filter;
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/core/search_goals_usecase.dart'
    as feature_goal_search;
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/core/sort_goals_usecase.dart'
    as feature_goal_sort;
import 'package:fantastic_guacamole/domain/usecases/update_goal.dart';
import 'package:fantastic_guacamole/domain/usecases/update_level.dart';
import 'package:fantastic_guacamole/domain/usecases/update_plan.dart';
import 'package:fantastic_guacamole/domain/usecases/update_project.dart';
import 'package:fantastic_guacamole/domain/usecases/update_routine.dart';
import 'package:fantastic_guacamole/domain/usecases/update_streak.dart';
import 'package:fantastic_guacamole/domain/usecases/update_subtask.dart';
import 'package:fantastic_guacamole/domain/usecases/update_task.dart';
import 'package:fantastic_guacamole/domain/usecases/update_xp.dart';
import 'package:fantastic_guacamole/engine/si/models/si_state.dart';
import 'package:fantastic_guacamole/state/controllers/si_state_controller.dart';
import 'package:fantastic_guacamole/state/services/extended_domain_service.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final domainTaskRepositoryProvider = Provider<ITaskRepository>((ref) {
  return ref.read(taskRepositoryProvider);
});

final domainNotificationRepositoryProvider = Provider<INotificationRepository>((
  ref,
) {
  return ref.watch(notificationsRepositoryProvider);
});

final domainGoalRepositoryProvider = Provider<IGoalRepository>((ref) {
  return ref.read(goalRepositoryProvider);
});

final domainInsightRepositoryProvider = Provider<IInsightRepository>((ref) {
  return ref.read(insightRepositoryProvider);
});

final domainLogRepositoryProvider = Provider<ILogRepository>((ref) {
  return ref.read(logRepositoryProvider);
});

final domainMemoryRepositoryProvider = Provider<IMemoryRepository>((ref) {
  return ref.watch(memoryRepositoryProvider);
});

final domainPlanRepositoryProvider = Provider<IPlanRepository>((ref) {
  return ref.read(planRepositoryProvider);
});

final domainProjectRepositoryProvider = Provider<IProjectRepository>((ref) {
  return ref.read(projectRepositoryProvider);
});

final domainProfileRepositoryProvider = Provider<IProfileRepository>((ref) {
  return ref.watch(profileRepositoryProvider);
});

final domainProgressionRepositoryProvider = Provider<IProgressionRepository>((
  ref,
) {
  return ref.watch(progressionRepositoryProvider);
});

final domainRoutineRepositoryProvider = Provider<IRoutineRepository>((ref) {
  return ref.read(routineRepositoryProvider);
});

final domainSubtaskRepositoryProvider = Provider<ISubtaskRepository>((ref) {
  return ref.read(subtaskRepositoryProvider);
});

final domainTimelineRepositoryProvider = Provider<ITimelineRepository>((ref) {
  return ref.read(timelineRepositoryProvider);
});

final domainThemeRepositoryProvider = Provider<IThemeRepository>((ref) {
  return ref.read(themeRepositoryProvider);
});

final domainIdentityRepositoryProvider = Provider<IIdentityRepository>((ref) {
  return ref.read(identityRepositoryProvider);
});

final domainSiRepositoryProvider = Provider<ISiRepository>((ref) {
  return _SiRepositoryAdapter(ref);
});

final extendedDomainRepositoryProvider = Provider<ExtendedDomainService>((ref) {
  final AccountStorageScope scope = ref.watch(accountStorageScopeProvider);
  final ExtendedDomainService service = ExtendedDomainService(
    storageScope: scope,
  );
  ref.onDispose(service.dispose);
  return service;
});

Future<void> cancelAndDrainExtendedDomainSessionState(Ref ref) async {
  await ref.read(extendedDomainRepositoryProvider).cancelAndDrain();
}

void invalidateExtendedDomainSessionState(Ref ref) {
  ref.invalidate(extendedDomainRepositoryProvider);
}

final getCoachMessagesUseCaseProvider = Provider<GetCoachMessages>((ref) {
  return GetCoachMessages(ref.watch(extendedDomainRepositoryProvider));
});

final saveCoachMessageUseCaseProvider = Provider<SaveCoachMessage>((ref) {
  return SaveCoachMessage(ref.watch(extendedDomainRepositoryProvider));
});

final getSiQueriesExtendedUseCaseProvider = Provider<GetSiQueriesExtended>((
  ref,
) {
  return GetSiQueriesExtended(ref.watch(extendedDomainRepositoryProvider));
});

final saveSiQueryExtendedUseCaseProvider = Provider<SaveSiQueryExtended>((ref) {
  return SaveSiQueryExtended(ref.watch(extendedDomainRepositoryProvider));
});

final getJournalEntriesUseCaseProvider = Provider<GetJournalEntries>((ref) {
  return GetJournalEntries(ref.watch(extendedDomainRepositoryProvider));
});

final saveJournalEntryUseCaseProvider = Provider<SaveJournalEntry>((ref) {
  return SaveJournalEntry(ref.watch(extendedDomainRepositoryProvider));
});

final getAnalyticsMetricsUseCaseProvider = Provider<GetAnalyticsMetrics>((ref) {
  return GetAnalyticsMetrics(ref.watch(extendedDomainRepositoryProvider));
});

final saveAnalyticsMetricUseCaseProvider = Provider<SaveAnalyticsMetric>((ref) {
  return SaveAnalyticsMetric(ref.watch(extendedDomainRepositoryProvider));
});

final getExtendedAppSettingsUseCaseProvider = Provider<GetExtendedAppSettings>((
  ref,
) {
  return GetExtendedAppSettings(ref.watch(extendedDomainRepositoryProvider));
});

final saveExtendedAppSettingUseCaseProvider = Provider<SaveExtendedAppSetting>((
  ref,
) {
  return SaveExtendedAppSetting(ref.watch(extendedDomainRepositoryProvider));
});

final extendedDomainBootstrapProvider = FutureProvider<void>((ref) async {
  final IExtendedDomainRepository repository = ref.watch(
    extendedDomainRepositoryProvider,
  );
  await repository.initialize();

  if (repository.getCoachMessages().isEmpty) {
    await ref
        .read(saveCoachMessageUseCaseProvider)
        .call(
          const CoachMessage(
            id: 'bootstrap.coach.welcome',
            label: 'Welcome to Smart Planner',
          ),
        );
  }

  if (repository.getSiQueries().isEmpty) {
    await ref
        .read(saveSiQueryExtendedUseCaseProvider)
        .call(
          const SiQuery(
            id: 'bootstrap.si.query.health',
            label: 'System health check',
          ),
        );
  }

  if (repository.getJournalEntries().isEmpty) {
    await ref
        .read(saveJournalEntryUseCaseProvider)
        .call(
          const JournalEntry(
            id: 'bootstrap.journal.entry.day0',
            label: 'Getting started reflection',
          ),
        );
  }

  if (repository.getAnalyticsMetrics().isEmpty) {
    await ref
        .read(saveAnalyticsMetricUseCaseProvider)
        .call(
          const AnalyticsMetric(
            id: 'bootstrap.analytics.productivity',
            label: 'Productivity baseline',
          ),
        );
  }

  if (repository.getSettings().isEmpty) {
    await ref
        .read(saveExtendedAppSettingUseCaseProvider)
        .call(
          const AppSetting(
            id: 'bootstrap.settings.coach.enabled',
            label: 'Coach enabled',
          ),
        );
  }
});

final coachMessagesProvider = Provider<List<CoachMessage>>((ref) {
  ref.watch(extendedDomainBootstrapProvider);
  return ref.watch(getCoachMessagesUseCaseProvider).call();
});

final siQueriesProvider = Provider<List<SiQuery>>((ref) {
  ref.watch(extendedDomainBootstrapProvider);
  return ref.watch(getSiQueriesExtendedUseCaseProvider).call();
});

final userIntentsProvider = Provider<List<UserIntent>>((ref) {
  ref.watch(extendedDomainBootstrapProvider);
  return ref.watch(extendedDomainRepositoryProvider).getUserIntents();
});

final journalEntriesProvider = Provider<List<JournalEntry>>((ref) {
  ref.watch(extendedDomainBootstrapProvider);
  return ref.watch(getJournalEntriesUseCaseProvider).call();
});

final analyticsMetricsProvider = Provider<List<AnalyticsMetric>>((ref) {
  ref.watch(extendedDomainBootstrapProvider);
  return ref.watch(getAnalyticsMetricsUseCaseProvider).call();
});

final appNotificationsProvider = Provider<List<AppNotification>>((ref) {
  ref.watch(extendedDomainBootstrapProvider);
  return ref.watch(extendedDomainRepositoryProvider).getAppNotifications();
});

final rewardsProvider = Provider<List<Reward>>((ref) {
  ref.watch(extendedDomainBootstrapProvider);
  return ref.watch(extendedDomainRepositoryProvider).getRewards();
});

final appThemesProvider = Provider<List<AppTheme>>((ref) {
  ref.watch(extendedDomainBootstrapProvider);
  return ref.watch(extendedDomainRepositoryProvider).getThemes();
});

final appSettingsProvider = Provider<List<AppSetting>>((ref) {
  ref.watch(extendedDomainBootstrapProvider);
  return ref.watch(getExtendedAppSettingsUseCaseProvider).call();
});

final syncStatesProvider = Provider<List<SyncState>>((ref) {
  ref.watch(extendedDomainBootstrapProvider);
  return ref.watch(extendedDomainRepositoryProvider).getSyncStates();
});

final offlineStatesProvider = Provider<List<OfflineState>>((ref) {
  ref.watch(extendedDomainBootstrapProvider);
  return ref.watch(extendedDomainRepositoryProvider).getOfflineStates();
});

final appErrorsProvider = Provider<List<AppError>>((ref) {
  ref.watch(extendedDomainBootstrapProvider);
  return ref.watch(extendedDomainRepositoryProvider).getAppErrors();
});

final recoveryStatesProvider = Provider<List<RecoveryState>>((ref) {
  ref.watch(extendedDomainBootstrapProvider);
  return ref.watch(extendedDomainRepositoryProvider).getRecoveryStates();
});

final subscriptionPlansProvider = Provider<List<SubscriptionPlanEntity>>((ref) {
  ref.watch(extendedDomainBootstrapProvider);
  return ref.watch(extendedDomainRepositoryProvider).getSubscriptionPlans();
});

final privacyPoliciesProvider = Provider<List<PrivacyPolicy>>((ref) {
  ref.watch(extendedDomainBootstrapProvider);
  return ref.watch(extendedDomainRepositoryProvider).getPrivacyPolicies();
});

final healthChecksProvider = Provider<List<HealthCheckResult>>((ref) {
  ref.watch(extendedDomainBootstrapProvider);
  return ref.watch(extendedDomainRepositoryProvider).getHealthChecks();
});

final getTasksUseCaseProvider = Provider<GetTasks>((ref) {
  return GetTasks(ref.read(domainTaskRepositoryProvider));
});

final getGoalsUseCaseProvider = Provider<GetGoals>((ref) {
  return GetGoals(ref.read(domainGoalRepositoryProvider));
});

final getInsightsUseCaseProvider = Provider<GetInsights>((ref) {
  return GetInsights(ref.read(domainInsightRepositoryProvider));
});

final addInsightUseCaseProvider = Provider<AddInsight>((ref) {
  return AddInsight(ref.read(domainInsightRepositoryProvider));
});

final generateInsightFromEventUseCaseProvider =
    Provider<GenerateInsightFromEvent>((ref) {
      return GenerateInsightFromEvent(
        ref.read(domainInsightRepositoryProvider),
      );
    });

final getLogsUseCaseProvider = Provider<GetLogs>((ref) {
  return GetLogs(ref.read(domainLogRepositoryProvider));
});

final addLogEntryUseCaseProvider = Provider<AddLogEntry>((ref) {
  return AddLogEntry(ref.read(domainLogRepositoryProvider));
});

final getCurrentThemeUseCaseProvider = Provider<GetCurrentTheme>((ref) {
  return GetCurrentTheme(ref.read(domainThemeRepositoryProvider));
});

final saveThemeUseCaseProvider = Provider<SaveTheme>((ref) {
  return SaveTheme(ref.read(domainThemeRepositoryProvider));
});

final getAllThemesUseCaseProvider = Provider<GetAllThemes>((ref) {
  return GetAllThemes(ref.read(domainThemeRepositoryProvider));
});

final switchThemeUseCaseProvider = Provider<SwitchTheme>((ref) {
  return SwitchTheme(ref.read(domainThemeRepositoryProvider));
});

final getIdentityProfileUseCaseProvider = Provider<GetIdentityProfile>((ref) {
  return GetIdentityProfile(ref.read(domainIdentityRepositoryProvider));
});

final saveIdentityProfileUseCaseProvider = Provider<SaveIdentityProfile>((ref) {
  return SaveIdentityProfile(ref.read(domainIdentityRepositoryProvider));
});

final createGoalUseCaseProvider = Provider<CreateGoal>((ref) {
  return CreateGoal(ref.read(domainGoalRepositoryProvider));
});

final featureCreateGoalUseCaseProvider =
    Provider<feature_goal_create.CreateGoalUsecase>((ref) {
      return feature_goal_create.CreateGoalUsecase(
        ref.read(domainGoalRepositoryProvider),
      );
    });

final featureUpdateGoalUseCaseProvider =
    Provider<feature_goal_update.UpdateGoalUsecase>((ref) {
      return feature_goal_update.UpdateGoalUsecase(
        ref.read(domainGoalRepositoryProvider),
      );
    });

final featureDeleteGoalUseCaseProvider =
    Provider<feature_goal_delete.DeleteGoalUsecase>((ref) {
      return feature_goal_delete.DeleteGoalUsecase(
        ref.read(domainGoalRepositoryProvider),
      );
    });

final featureDuplicateGoalUseCaseProvider =
    Provider<feature_goal_duplicate.DuplicateGoalUsecase>((ref) {
      return feature_goal_duplicate.DuplicateGoalUsecase(
        ref.read(domainGoalRepositoryProvider),
      );
    });

final updateGoalUseCaseProvider = Provider<UpdateGoal>((ref) {
  return UpdateGoal(ref.read(domainGoalRepositoryProvider));
});

final deleteGoalUseCaseProvider = Provider<DeleteGoal>((ref) {
  return DeleteGoal(ref.read(domainGoalRepositoryProvider));
});

final completeGoalUseCaseProvider = Provider<CompleteGoal>((ref) {
  return CompleteGoal(ref.read(domainGoalRepositoryProvider));
});

final archiveGoalUseCaseProvider = Provider<ArchiveGoal>((ref) {
  return ArchiveGoal(ref.read(domainGoalRepositoryProvider));
});

final reopenGoalUseCaseProvider = Provider<ReopenGoal>((ref) {
  return ReopenGoal(ref.read(domainGoalRepositoryProvider));
});

final saveGoalsUseCaseProvider = Provider<SaveGoals>((ref) {
  return SaveGoals(ref.read(domainGoalRepositoryProvider));
});

final viewGoalUseCaseProvider = Provider<ViewGoalUsecase>((ref) {
  return ViewGoalUsecase(ref.read(domainGoalRepositoryProvider));
});

final viewGoalDetailsUseCaseProvider = Provider<ViewGoalDetailsUsecase>((ref) {
  return ViewGoalDetailsUsecase(ref.read(domainGoalRepositoryProvider));
});

final viewActiveGoalsUseCaseProvider = Provider<ViewActiveGoalsUsecase>((ref) {
  return ViewActiveGoalsUsecase(ref.read(domainGoalRepositoryProvider));
});

final viewArchivedGoalsUseCaseProvider = Provider<ViewArchivedGoalsUsecase>((
  ref,
) {
  return ViewArchivedGoalsUsecase(ref.read(domainGoalRepositoryProvider));
});

final viewCompletedGoalsUseCaseProvider = Provider<ViewCompletedGoalsUsecase>((
  ref,
) {
  return ViewCompletedGoalsUsecase(ref.read(domainGoalRepositoryProvider));
});

final viewOverdueGoalsUseCaseProvider = Provider<ViewOverdueGoalsUsecase>((
  ref,
) {
  return ViewOverdueGoalsUsecase(ref.read(domainGoalRepositoryProvider));
});

final viewGoalTimelineUseCaseProvider = Provider<ViewGoalTimelineUsecase>((
  ref,
) {
  return ViewGoalTimelineUsecase(ref.read(domainTimelineRepositoryProvider));
});

final viewGoalHistoryUseCaseProvider = Provider<ViewGoalHistoryUsecase>((ref) {
  return ViewGoalHistoryUsecase(ref.read(domainTimelineRepositoryProvider));
});

final viewGoalActivityUseCaseProvider = Provider<ViewGoalActivityUsecase>((
  ref,
) {
  return ViewGoalActivityUsecase(ref.read(domainTimelineRepositoryProvider));
});

final getProjectsUseCaseProvider = Provider<GetProjects>((ref) {
  return GetProjects(ref.read(domainProjectRepositoryProvider));
});

final createProjectUseCaseProvider = Provider<CreateProject>((ref) {
  return CreateProject(ref.read(domainProjectRepositoryProvider));
});

final updateProjectUseCaseProvider = Provider<UpdateProject>((ref) {
  return UpdateProject(ref.read(domainProjectRepositoryProvider));
});

final deleteProjectUseCaseProvider = Provider<DeleteProject>((ref) {
  return DeleteProject(ref.read(domainProjectRepositoryProvider));
});

final saveProjectsUseCaseProvider = Provider<SaveProjects>((ref) {
  return SaveProjects(ref.read(domainProjectRepositoryProvider));
});

final getRoutinesUseCaseProvider = Provider<GetRoutines>((ref) {
  return GetRoutines(ref.read(domainRoutineRepositoryProvider));
});

final createRoutineUseCaseProvider = Provider<CreateRoutine>((ref) {
  return CreateRoutine(ref.read(domainRoutineRepositoryProvider));
});

final updateRoutineUseCaseProvider = Provider<UpdateRoutine>((ref) {
  return UpdateRoutine(ref.read(domainRoutineRepositoryProvider));
});

final deleteRoutineUseCaseProvider = Provider<DeleteRoutine>((ref) {
  return DeleteRoutine(ref.read(domainRoutineRepositoryProvider));
});

final saveRoutinesUseCaseProvider = Provider<SaveRoutines>((ref) {
  return SaveRoutines(ref.read(domainRoutineRepositoryProvider));
});

// Habit-semantics aliases over the legacy routine repository/usecases.
// These aliases allow gradual migration without breaking existing callers.
final getHabitsFromRoutineUseCaseProvider = Provider<GetRoutines>((ref) {
  return ref.read(getRoutinesUseCaseProvider);
});

final createHabitFromRoutineUseCaseProvider = Provider<CreateRoutine>((ref) {
  return ref.read(createRoutineUseCaseProvider);
});

final updateHabitFromRoutineUseCaseProvider = Provider<UpdateRoutine>((ref) {
  return ref.read(updateRoutineUseCaseProvider);
});

final deleteHabitFromRoutineUseCaseProvider = Provider<DeleteRoutine>((ref) {
  return ref.read(deleteRoutineUseCaseProvider);
});

final saveHabitsFromRoutineUseCaseProvider = Provider<SaveRoutines>((ref) {
  return ref.read(saveRoutinesUseCaseProvider);
});

final getSubtasksUseCaseProvider = Provider<GetSubtasks>((ref) {
  return GetSubtasks(ref.read(domainSubtaskRepositoryProvider));
});

final createSubtaskUseCaseProvider = Provider<CreateSubtask>((ref) {
  return CreateSubtask(ref.read(domainSubtaskRepositoryProvider));
});

final updateSubtaskUseCaseProvider = Provider<UpdateSubtask>((ref) {
  return UpdateSubtask(ref.read(domainSubtaskRepositoryProvider));
});

final deleteSubtaskUseCaseProvider = Provider<DeleteSubtask>((ref) {
  return DeleteSubtask(ref.read(domainSubtaskRepositoryProvider));
});

final saveSubtasksUseCaseProvider = Provider<SaveSubtasks>((ref) {
  return SaveSubtasks(ref.read(domainSubtaskRepositoryProvider));
});

final getMemoriesUseCaseProvider = Provider<GetMemories>((ref) {
  return GetMemories(ref.watch(domainMemoryRepositoryProvider));
});

final saveMemoryUseCaseProvider = Provider<SaveMemory>((ref) {
  return SaveMemory(ref.watch(domainMemoryRepositoryProvider));
});

final deleteMemoryUseCaseProvider = Provider<DeleteMemory>((ref) {
  return DeleteMemory(ref.watch(domainMemoryRepositoryProvider));
});

final saveMemoriesUseCaseProvider = Provider<SaveMemories>((ref) {
  return SaveMemories(ref.watch(domainMemoryRepositoryProvider));
});

final getPlanUseCaseProvider = Provider<GetPlan>((ref) {
  return GetPlan(ref.read(domainPlanRepositoryProvider));
});

final createPlanUseCaseProvider = Provider<CreatePlan>((ref) {
  return CreatePlan(ref.read(domainPlanRepositoryProvider));
});

final updatePlanUseCaseProvider = Provider<UpdatePlan>((ref) {
  return UpdatePlan(ref.read(domainPlanRepositoryProvider));
});

final getProfileUseCaseProvider = Provider<GetProfile>((ref) {
  return GetProfile(ref.watch(domainProfileRepositoryProvider));
});

final getProgressionUseCaseProvider = Provider<GetProgression>((ref) {
  return GetProgression(ref.watch(domainProgressionRepositoryProvider));
});

final updateStreakUseCaseProvider = Provider<UpdateStreak>((ref) {
  return UpdateStreak(ref.watch(domainProgressionRepositoryProvider));
});

final updateXpUseCaseProvider = Provider<UpdateXp>((ref) {
  return UpdateXp(ref.watch(domainProgressionRepositoryProvider));
});

final updateLevelUseCaseProvider = Provider<UpdateLevel>((ref) {
  return UpdateLevel(ref.watch(domainProgressionRepositoryProvider));
});

final getTimelineEventsUseCaseProvider = Provider<GetTimelineEvents>((ref) {
  return GetTimelineEvents(ref.read(domainTimelineRepositoryProvider));
});

final addTimelineEventUseCaseProvider = Provider<AddTimelineEvent>((ref) {
  return AddTimelineEvent(ref.read(domainTimelineRepositoryProvider));
});

final removeTimelineEventUseCaseProvider = Provider<RemoveTimelineEvent>((ref) {
  return RemoveTimelineEvent(ref.read(domainTimelineRepositoryProvider));
});

final saveTimelineEventsUseCaseProvider = Provider<SaveTimelineEvents>((ref) {
  return SaveTimelineEvents(ref.read(domainTimelineRepositoryProvider));
});

final createTaskUseCaseProvider = Provider<CreateTask>((ref) {
  return CreateTask(
    ref.read(domainTaskRepositoryProvider),
    generateSiDecision: ref.read(generateSiDecisionUseCaseProvider),
  );
});

final completeTaskUseCaseProvider = Provider<CompleteTask>((ref) {
  return CompleteTask(ref.read(domainTaskRepositoryProvider));
});

final updateTaskUseCaseProvider = Provider<UpdateTask>((ref) {
  return UpdateTask(ref.read(domainTaskRepositoryProvider));
});

final deleteTaskUseCaseProvider = Provider<DeleteTask>((ref) {
  return DeleteTask(ref.read(domainTaskRepositoryProvider));
});

final scheduleNotificationUseCaseProvider = Provider<ScheduleNotification>((
  ref,
) {
  return ScheduleNotification(ref.read(domainNotificationRepositoryProvider));
});

final cancelNotificationUseCaseProvider = Provider<CancelNotification>((ref) {
  return CancelNotification(ref.read(domainNotificationRepositoryProvider));
});

final generateSiDecisionUseCaseProvider = Provider<GenerateSiDecision>((ref) {
  return GenerateSiDecision(
    ref.read(domainTaskRepositoryProvider),
    ref.read(domainSiRepositoryProvider),
  );
});

const String _siDecisionSnapshotKey = 'si_decision_snapshot_v1';
const Duration _siDecisionSnapshotTtl = Duration(minutes: 20);

final domainSiDecisionProvider = FutureProvider<Task?>((ref) async {
  final Task? cached = await _loadCachedSiDecisionTask(ref);
  if (cached != null) {
    return cached;
  }

  final SiDecisionEntity decision = await ref
      .read(generateSiDecisionUseCaseProvider)
      .call();
  final String? selectedTaskId = decision.selectedTaskId;
  if (selectedTaskId == null || selectedTaskId.isEmpty) {
    return null;
  }

  final TaskEntity? task = await ref
      .read(domainTaskRepositoryProvider)
      .getTaskById(selectedTaskId);
  final Task? selected = task == null ? null : _taskFromEntity(task);
  await _persistSiDecisionSnapshot(ref, selectedTaskId: selectedTaskId);
  return selected;
});

Future<Task?> _loadCachedSiDecisionTask(Ref ref) async {
  try {
    final String? raw = await ref
        .read(secureStoreProvider)
        .readString(_siDecisionSnapshotKey);
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    final Object? decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }
    final String selectedTaskId =
        (decoded['selectedTaskId'] as String?)?.trim() ?? '';
    if (selectedTaskId.isEmpty) {
      return null;
    }
    final DateTime? cachedAt = DateTime.tryParse(
      (decoded['cachedAt'] as String?) ?? '',
    );
    if (cachedAt == null ||
        DateTime.now().difference(cachedAt) > _siDecisionSnapshotTtl) {
      return null;
    }
    final TaskEntity? task = await ref
        .read(domainTaskRepositoryProvider)
        .getTaskById(selectedTaskId);
    if (task == null) {
      return null;
    }
    return _taskFromEntity(task);
  } on Object {
    return null;
  }
}

Future<void> _persistSiDecisionSnapshot(
  Ref ref, {
  required String selectedTaskId,
}) async {
  try {
    await ref
        .read(secureStoreProvider)
        .writeString(
          _siDecisionSnapshotKey,
          jsonEncode(<String, String>{
            'selectedTaskId': selectedTaskId,
            'cachedAt': DateTime.now().toIso8601String(),
          }),
        );
  } on Object {
    // Non-fatal: decision can still be recomputed live.
  }
}

Task _taskFromEntity(TaskEntity task) {
  return Task(
    id: task.id,
    title: task.title,
    priority: task.priority,
    difficulty: task.difficulty,
    energyRequired: task.energyRequired,
  );
}

class _SiRepositoryAdapter implements ISiRepository {
  _SiRepositoryAdapter(this._ref);

  final Ref _ref;

  @override
  Future<SiStateEntity?> getCurrentState() async {
    final SIState state = _ref.read(siStateProvider);
    return SiStateEntity(
      energy: state.energy,
      focus: (state.energy * (1 - state.fatigue)).clamp(0.0, 1.0),
      fatigue: state.fatigue,
    );
  }

  @override
  Future<void> saveState(SiStateEntity state) async {
    _ref
        .read(siStateProvider.notifier)
        .replaceState(energy: state.energy, fatigue: state.fatigue);
  }
}

final featureSearchGoalsUseCaseProvider =
    Provider<feature_goal_search.SearchGoalsUsecase>((ref) {
      return feature_goal_search.SearchGoalsUsecase(
        ref.read(domainGoalRepositoryProvider),
      );
    });

final featureFilterGoalsUseCaseProvider =
    Provider<feature_goal_filter.FilterGoalsUsecase>((ref) {
      return feature_goal_filter.FilterGoalsUsecase(
        ref.read(domainGoalRepositoryProvider),
      );
    });

final featureSortGoalsUseCaseProvider =
    Provider<feature_goal_sort.SortGoalsUsecase>((ref) {
      return feature_goal_sort.SortGoalsUsecase(
        ref.read(domainGoalRepositoryProvider),
      );
    });

final featureCreateDailyGoalUseCaseProvider =
    Provider<feature_goal_daily.CreateDailyGoalUsecase>((ref) {
      return feature_goal_daily.CreateDailyGoalUsecase(
        ref.read(domainGoalRepositoryProvider),
      );
    });

final featureCreateWeeklyGoalUseCaseProvider =
    Provider<feature_goal_weekly.CreateWeeklyGoalUsecase>((ref) {
      return feature_goal_weekly.CreateWeeklyGoalUsecase(
        ref.read(domainGoalRepositoryProvider),
      );
    });

final featureCreateMonthlyGoalUseCaseProvider =
    Provider<feature_goal_monthly.CreateMonthlyGoalUsecase>((ref) {
      return feature_goal_monthly.CreateMonthlyGoalUsecase(
        ref.read(domainGoalRepositoryProvider),
      );
    });

final featureCreateYearlyGoalUseCaseProvider =
    Provider<feature_goal_yearly.CreateYearlyGoalUsecase>((ref) {
      return feature_goal_yearly.CreateYearlyGoalUsecase(
        ref.read(domainGoalRepositoryProvider),
      );
    });

final featureCreateSmartGoalUseCaseProvider =
    Provider<feature_goal_smart.CreateSmartGoalUsecase>((ref) {
      return feature_goal_smart.CreateSmartGoalUsecase(
        ref.read(domainGoalRepositoryProvider),
      );
    });

final featureCreateMicroGoalUseCaseProvider =
    Provider<feature_goal_micro.CreateMicroGoalUsecase>((ref) {
      return feature_goal_micro.CreateMicroGoalUsecase(
        ref.read(domainGoalRepositoryProvider),
      );
    });

final featureCreateStretchGoalUseCaseProvider =
    Provider<feature_goal_stretch.CreateStretchGoalUsecase>((ref) {
      return feature_goal_stretch.CreateStretchGoalUsecase(
        ref.read(domainGoalRepositoryProvider),
      );
    });

final featureCreateLifetimeGoalUseCaseProvider =
    Provider<feature_goal_lifetime.CreateLifetimeGoalUsecase>((ref) {
      return feature_goal_lifetime.CreateLifetimeGoalUsecase(
        ref.read(domainGoalRepositoryProvider),
      );
    });

final featureCreateCareerGoalUseCaseProvider =
    Provider<feature_goal_career.CreateCareerGoalUsecase>((ref) {
      return feature_goal_career.CreateCareerGoalUsecase(
        ref.read(domainGoalRepositoryProvider),
      );
    });

final featureCreateFinancialGoalUseCaseProvider =
    Provider<feature_goal_financial.CreateFinancialGoalUsecase>((ref) {
      return feature_goal_financial.CreateFinancialGoalUsecase(
        ref.read(domainGoalRepositoryProvider),
      );
    });

final featureCreateFitnessGoalUseCaseProvider =
    Provider<feature_goal_fitness.CreateFitnessGoalUsecase>((ref) {
      return feature_goal_fitness.CreateFitnessGoalUsecase(
        ref.read(domainGoalRepositoryProvider),
      );
    });

final featureCreateHealthGoalUseCaseProvider =
    Provider<feature_goal_health.CreateHealthGoalUsecase>((ref) {
      return feature_goal_health.CreateHealthGoalUsecase(
        ref.read(domainGoalRepositoryProvider),
      );
    });

final featureCreateLearningGoalUseCaseProvider =
    Provider<feature_goal_learning.CreateLearningGoalUsecase>((ref) {
      return feature_goal_learning.CreateLearningGoalUsecase(
        ref.read(domainGoalRepositoryProvider),
      );
    });

final featureCreatePersonalGoalUseCaseProvider =
    Provider<feature_goal_personal.CreatePersonalGoalUsecase>((ref) {
      return feature_goal_personal.CreatePersonalGoalUsecase(
        ref.read(domainGoalRepositoryProvider),
      );
    });

final featureCreateProductivityGoalUseCaseProvider =
    Provider<feature_goal_productivity.CreateProductivityGoalUsecase>((ref) {
      return feature_goal_productivity.CreateProductivityGoalUsecase(
        ref.read(domainGoalRepositoryProvider),
      );
    });

final featureCreateRelationshipGoalUseCaseProvider =
    Provider<feature_goal_relationship.CreateRelationshipGoalUsecase>((ref) {
      return feature_goal_relationship.CreateRelationshipGoalUsecase(
        ref.read(domainGoalRepositoryProvider),
      );
    });

final featureCreateSpiritualGoalUseCaseProvider =
    Provider<feature_goal_spiritual.CreateSpiritualGoalUsecase>((ref) {
      return feature_goal_spiritual.CreateSpiritualGoalUsecase(
        ref.read(domainGoalRepositoryProvider),
      );
    });

final featureCalculateGoalScoreUseCaseProvider =
    Provider<feature_goal_score.CalculateGoalScoreUsecase>((ref) {
      return feature_goal_score.CalculateGoalScoreUsecase(
        ref.read(domainGoalRepositoryProvider),
        ref.read(domainTaskRepositoryProvider),
      );
    });

final featureCalculateGoalSuccessRateUseCaseProvider =
    Provider<feature_goal_success_rate.CalculateGoalSuccessRateUsecase>((ref) {
      return feature_goal_success_rate.CalculateGoalSuccessRateUsecase(
        ref.read(domainGoalRepositoryProvider),
        ref.read(domainTaskRepositoryProvider),
      );
    });

final featureIncrementGoalProgressUseCaseProvider =
    Provider<feature_goal_progress_increment.IncrementGoalProgressUsecase>((
      ref,
    ) {
      return feature_goal_progress_increment.IncrementGoalProgressUsecase(
        ref.read(domainGoalRepositoryProvider),
        ref.read(domainTaskRepositoryProvider),
      );
    });

final featureDecrementGoalProgressUseCaseProvider =
    Provider<feature_goal_progress_decrement.DecrementGoalProgressUsecase>((
      ref,
    ) {
      return feature_goal_progress_decrement.DecrementGoalProgressUsecase(
        ref.read(domainGoalRepositoryProvider),
        ref.read(domainTaskRepositoryProvider),
      );
    });

final featureResetGoalProgressUseCaseProvider =
    Provider<feature_goal_progress_reset.ResetGoalProgressUsecase>((ref) {
      return feature_goal_progress_reset.ResetGoalProgressUsecase(
        ref.read(domainGoalRepositoryProvider),
        ref.read(domainTaskRepositoryProvider),
      );
    });

final featureUpdateGoalProgressUseCaseProvider =
    Provider<feature_goal_progress_update.UpdateGoalProgressUsecase>((ref) {
      return feature_goal_progress_update.UpdateGoalProgressUsecase(
        ref.read(domainGoalRepositoryProvider),
        ref.read(domainTaskRepositoryProvider),
      );
    });

final featureCreateMilestoneUseCaseProvider =
    Provider<feature_goal_create_milestone.CreateMilestoneUsecase>((ref) {
      return feature_goal_create_milestone.CreateMilestoneUsecase(
        ref.read(domainGoalRepositoryProvider),
        ref.read(domainTimelineRepositoryProvider),
      );
    });

final featureUpdateMilestoneUseCaseProvider =
    Provider<feature_goal_update_milestone.UpdateMilestoneUsecase>((ref) {
      return feature_goal_update_milestone.UpdateMilestoneUsecase(
        ref.read(domainTimelineRepositoryProvider),
      );
    });

final featureDeleteMilestoneUseCaseProvider =
    Provider<feature_goal_delete_milestone.DeleteMilestoneUsecase>((ref) {
      return feature_goal_delete_milestone.DeleteMilestoneUsecase(
        ref.read(domainTimelineRepositoryProvider),
      );
    });

final featureCompleteMilestoneUseCaseProvider =
    Provider<feature_goal_complete_milestone.CompleteMilestoneUsecase>((ref) {
      return feature_goal_complete_milestone.CompleteMilestoneUsecase(
        ref.read(domainTimelineRepositoryProvider),
      );
    });

final featureReopenMilestoneUseCaseProvider =
    Provider<feature_goal_reopen_milestone.ReopenMilestoneUsecase>((ref) {
      return feature_goal_reopen_milestone.ReopenMilestoneUsecase(
        ref.read(domainTimelineRepositoryProvider),
      );
    });

final featureCreateSubgoalUseCaseProvider =
    Provider<feature_goal_create_subgoal.CreateSubgoalUsecase>((ref) {
      return feature_goal_create_subgoal.CreateSubgoalUsecase(
        ref.read(domainGoalRepositoryProvider),
        ref.read(domainTimelineRepositoryProvider),
      );
    });

final featureUpdateSubgoalUseCaseProvider =
    Provider<feature_goal_update_subgoal.UpdateSubgoalUsecase>((ref) {
      return feature_goal_update_subgoal.UpdateSubgoalUsecase(
        ref.read(domainTimelineRepositoryProvider),
      );
    });

final featureDeleteSubgoalUseCaseProvider =
    Provider<feature_goal_delete_subgoal.DeleteSubgoalUsecase>((ref) {
      return feature_goal_delete_subgoal.DeleteSubgoalUsecase(
        ref.read(domainTimelineRepositoryProvider),
      );
    });

final featureCompleteSubgoalUseCaseProvider =
    Provider<feature_goal_complete_subgoal.CompleteSubgoalUsecase>((ref) {
      return feature_goal_complete_subgoal.CompleteSubgoalUsecase(
        ref.read(domainTimelineRepositoryProvider),
      );
    });

final featureDetectGoalConflictsUseCaseProvider =
    Provider<feature_goal_conflicts.DetectGoalConflictsUsecase>((ref) {
      return feature_goal_conflicts.DetectGoalConflictsUsecase(
        ref.read(domainGoalRepositoryProvider),
      );
    });

final featureDetectGoalRiskUseCaseProvider =
    Provider<feature_goal_risk.DetectGoalRiskUsecase>((ref) {
      return feature_goal_risk.DetectGoalRiskUsecase(
        ref.read(domainGoalRepositoryProvider),
      );
    });

final featureDetectGoalStagnationUseCaseProvider =
    Provider<feature_goal_stagnation.DetectGoalStagnationUsecase>((ref) {
      return feature_goal_stagnation.DetectGoalStagnationUsecase(
        ref.read(domainGoalRepositoryProvider),
      );
    });

final featurePredictGoalCompletionUseCaseProvider =
    Provider<feature_goal_completion_prediction.PredictGoalCompletionUsecase>((
      ref,
    ) {
      return feature_goal_completion_prediction.PredictGoalCompletionUsecase(
        ref.read(domainGoalRepositoryProvider),
      );
    });

final featurePredictGoalSuccessUseCaseProvider =
    Provider<feature_goal_success_prediction.PredictGoalSuccessUsecase>((ref) {
      return feature_goal_success_prediction.PredictGoalSuccessUsecase(
        ref.read(domainGoalRepositoryProvider),
      );
    });

final featureViewGoalAnalyticsUseCaseProvider =
    Provider<feature_goal_analytics.ViewGoalAnalyticsUsecase>((ref) {
      return feature_goal_analytics.ViewGoalAnalyticsUsecase(
        ref.read(domainGoalRepositoryProvider),
      );
    });

final featureViewGoalCompletionRateUseCaseProvider =
    Provider<feature_goal_completion_rate.ViewGoalCompletionRateUsecase>((ref) {
      return feature_goal_completion_rate.ViewGoalCompletionRateUsecase(
        ref.read(domainGoalRepositoryProvider),
      );
    });

final featureViewGoalStreaksUseCaseProvider =
    Provider<feature_goal_streaks.ViewGoalStreaksUsecase>((ref) {
      return feature_goal_streaks.ViewGoalStreaksUsecase(
        ref.read(domainGoalRepositoryProvider),
      );
    });

final featureViewGoalTrendsUseCaseProvider =
    Provider<feature_goal_trends.ViewGoalTrendsUsecase>((ref) {
      return feature_goal_trends.ViewGoalTrendsUsecase(
        ref.read(domainGoalRepositoryProvider),
      );
    });

final featureGenerateGoalBreakdownUseCaseProvider =
    Provider<feature_goal_breakdown.GenerateGoalBreakdownUsecase>((ref) {
      return feature_goal_breakdown.GenerateGoalBreakdownUsecase(
        ref.read(domainGoalRepositoryProvider),
        ref.read(domainTaskRepositoryProvider),
      );
    });

final featureGenerateGoalInsightsUseCaseProvider =
    Provider<feature_goal_insights.GenerateGoalInsightsUsecase>((ref) {
      return feature_goal_insights.GenerateGoalInsightsUsecase(
        ref.read(domainGoalRepositoryProvider),
      );
    });

final featureGenerateGoalPlanUseCaseProvider =
    Provider<feature_goal_plan.GenerateGoalPlanUsecase>((ref) {
      return feature_goal_plan.GenerateGoalPlanUsecase(
        ref.read(domainGoalRepositoryProvider),
        ref.read(domainTaskRepositoryProvider),
      );
    });

final featureGenerateGoalRecommendationsUseCaseProvider =
    Provider<feature_goal_recommendations.GenerateGoalRecommendationsUsecase>((
      ref,
    ) {
      return feature_goal_recommendations.GenerateGoalRecommendationsUsecase(
        ref.read(domainGoalRepositoryProvider),
      );
    });

final featureGenerateGoalSummaryUseCaseProvider =
    Provider<feature_goal_summary.GenerateGoalSummaryUsecase>((ref) {
      return feature_goal_summary.GenerateGoalSummaryUsecase(
        ref.read(domainGoalRepositoryProvider),
      );
    });

final featureRecommendGoalsUseCaseProvider =
    Provider<feature_goal_recommend_goals.RecommendGoalsUsecase>((ref) {
      return feature_goal_recommend_goals.RecommendGoalsUsecase(
        ref.read(domainGoalRepositoryProvider),
      );
    });

final featureRecommendNextActionUseCaseProvider =
    Provider<feature_goal_next_action.RecommendNextActionUsecase>((ref) {
      return feature_goal_next_action.RecommendNextActionUsecase(
        ref.read(domainGoalRepositoryProvider),
        ref.read(domainTaskRepositoryProvider),
      );
    });

final featureSetGoalDeadlineUseCaseProvider =
    Provider<feature_goal_set_deadline.SetGoalDeadlineUsecase>((ref) {
      return feature_goal_set_deadline.SetGoalDeadlineUsecase(
        ref.read(domainGoalRepositoryProvider),
      );
    });

final featureUpdateGoalDeadlineUseCaseProvider =
    Provider<feature_goal_update_deadline.UpdateGoalDeadlineUsecase>((ref) {
      return feature_goal_update_deadline.UpdateGoalDeadlineUsecase(
        ref.read(domainGoalRepositoryProvider),
      );
    });

final featureRemoveGoalDeadlineUseCaseProvider =
    Provider<feature_goal_remove_deadline.RemoveGoalDeadlineUsecase>((ref) {
      return feature_goal_remove_deadline.RemoveGoalDeadlineUsecase(
        ref.read(domainGoalRepositoryProvider),
      );
    });

final featureStartGoalUseCaseProvider =
    Provider<feature_goal_start.StartGoalUsecase>((ref) {
      return feature_goal_start.StartGoalUsecase(
        ref.read(domainGoalRepositoryProvider),
        ref.read(domainTimelineRepositoryProvider),
      );
    });

final featurePauseGoalUseCaseProvider =
    Provider<feature_goal_pause.PauseGoalUsecase>((ref) {
      return feature_goal_pause.PauseGoalUsecase(
        ref.read(domainGoalRepositoryProvider),
        ref.read(domainTimelineRepositoryProvider),
      );
    });

final featureResumeGoalUseCaseProvider =
    Provider<feature_goal_resume.ResumeGoalUsecase>((ref) {
      return feature_goal_resume.ResumeGoalUsecase(
        ref.read(domainGoalRepositoryProvider),
        ref.read(domainTimelineRepositoryProvider),
      );
    });

final featureReopenGoalUseCaseProvider =
    Provider<feature_goal_reopen.ReopenGoalUsecase>((ref) {
      return feature_goal_reopen.ReopenGoalUsecase(
        ref.read(domainGoalRepositoryProvider),
        ref.read(domainTimelineRepositoryProvider),
      );
    });

final featureAbandonGoalUseCaseProvider =
    Provider<feature_goal_abandon.AbandonGoalUsecase>((ref) {
      return feature_goal_abandon.AbandonGoalUsecase(
        ref.read(domainGoalRepositoryProvider),
        ref.read(domainTimelineRepositoryProvider),
      );
    });

final featureLifecycleCompleteGoalUseCaseProvider =
    Provider<feature_goal_lifecycle_complete.CompleteGoalUsecase>((ref) {
      return feature_goal_lifecycle_complete.CompleteGoalUsecase(
        ref.read(domainGoalRepositoryProvider),
        ref.read(domainTimelineRepositoryProvider),
      );
    });

final featureMarkGoalCompletedUseCaseProvider =
    Provider<feature_goal_mark_completed.MarkGoalCompletedUsecase>((ref) {
      return feature_goal_mark_completed.MarkGoalCompletedUsecase(
        ref.read(domainGoalRepositoryProvider),
        ref.read(domainTimelineRepositoryProvider),
      );
    });

final featureMarkGoalFailedUseCaseProvider =
    Provider<feature_goal_mark_failed.MarkGoalFailedUsecase>((ref) {
      return feature_goal_mark_failed.MarkGoalFailedUsecase(
        ref.read(domainGoalRepositoryProvider),
        ref.read(domainTimelineRepositoryProvider),
      );
    });

final featureMarkGoalInProgressUseCaseProvider =
    Provider<feature_goal_mark_in_progress.MarkGoalInProgressUsecase>((ref) {
      return feature_goal_mark_in_progress.MarkGoalInProgressUsecase(
        ref.read(domainGoalRepositoryProvider),
        ref.read(domainTimelineRepositoryProvider),
      );
    });

final featureLinkTaskToGoalUseCaseProvider =
    Provider<feature_goal_link_task.LinkTaskToGoalUsecase>((ref) {
      return feature_goal_link_task.LinkTaskToGoalUsecase(
        ref.read(domainGoalRepositoryProvider),
        ref.read(domainTaskRepositoryProvider),
      );
    });

final featureUnlinkTaskFromGoalUseCaseProvider =
    Provider<feature_goal_unlink_task.UnlinkTaskFromGoalUsecase>((ref) {
      return feature_goal_unlink_task.UnlinkTaskFromGoalUsecase(
        ref.read(domainGoalRepositoryProvider),
        ref.read(domainTaskRepositoryProvider),
      );
    });

final featureCreateGoalReminderUseCaseProvider =
    Provider<feature_goal_create_reminder.CreateGoalReminderUsecase>((ref) {
      return feature_goal_create_reminder.CreateGoalReminderUsecase(
        ref.read(domainGoalRepositoryProvider),
        ref.read(reminderOrchestratorServiceProvider),
      );
    });

final featureUpdateGoalReminderUseCaseProvider =
    Provider<feature_goal_update_reminder.UpdateGoalReminderUsecase>((ref) {
      return feature_goal_update_reminder.UpdateGoalReminderUsecase(
        ref.read(domainGoalRepositoryProvider),
        ref.read(reminderOrchestratorServiceProvider),
      );
    });

final featureDeleteGoalReminderUseCaseProvider =
    Provider<feature_goal_delete_reminder.DeleteGoalReminderUsecase>((ref) {
      return feature_goal_delete_reminder.DeleteGoalReminderUsecase(
        ref.read(domainGoalRepositoryProvider),
        ref.read(reminderOrchestratorServiceProvider),
      );
    });

final featureDismissGoalReminderUseCaseProvider =
    Provider<feature_goal_dismiss_reminder.DismissGoalReminderUsecase>((ref) {
      return feature_goal_dismiss_reminder.DismissGoalReminderUsecase(
        ref.read(domainGoalRepositoryProvider),
        ref.read(domainTimelineRepositoryProvider),
      );
    });

final featureSnoozeGoalReminderUseCaseProvider =
    Provider<feature_goal_snooze_reminder.SnoozeGoalReminderUsecase>((ref) {
      return feature_goal_snooze_reminder.SnoozeGoalReminderUsecase(
        ref.read(domainGoalRepositoryProvider),
        ref.read(domainTimelineRepositoryProvider),
      );
    });

final featureAwardGoalAchievementUseCaseProvider =
    Provider<feature_goal_award.AwardGoalAchievementUsecase>((ref) {
      return feature_goal_award.AwardGoalAchievementUsecase(
        ref.read(domainGoalRepositoryProvider),
      );
    });

final featureCelebrateGoalCompletionUseCaseProvider =
    Provider<feature_goal_celebrate.CelebrateGoalCompletionUsecase>((ref) {
      return feature_goal_celebrate.CelebrateGoalCompletionUsecase(
        ref.read(domainGoalRepositoryProvider),
      );
    });

final featureCreateGoalFromTemplateUseCaseProvider =
    Provider<feature_goal_from_template.CreateGoalFromTemplateUsecase>((ref) {
      return feature_goal_from_template.CreateGoalFromTemplateUsecase(
        ref.read(domainGoalRepositoryProvider),
      );
    });

final featureSaveGoalAsTemplateUseCaseProvider =
    Provider<feature_goal_save_template.SaveGoalAsTemplateUsecase>((ref) {
      return feature_goal_save_template.SaveGoalAsTemplateUsecase(
        ref.read(domainGoalRepositoryProvider),
      );
    });

final featureUpdateGoalTemplateUseCaseProvider =
    Provider<feature_goal_update_template.UpdateGoalTemplateUsecase>((ref) {
      return const feature_goal_update_template.UpdateGoalTemplateUsecase();
    });

final featureCreateGoalCategoryUseCaseProvider =
    Provider<feature_goal_category_create.CreateGoalCategoryUsecase>((ref) {
      return const feature_goal_category_create.CreateGoalCategoryUsecase();
    });

final featureUpdateGoalCategoryUseCaseProvider =
    Provider<feature_goal_category_update.UpdateGoalCategoryUsecase>((ref) {
      return const feature_goal_category_update.UpdateGoalCategoryUsecase();
    });

final featureDeleteGoalCategoryUseCaseProvider =
    Provider<feature_goal_category_delete.DeleteGoalCategoryUsecase>((ref) {
      return const feature_goal_category_delete.DeleteGoalCategoryUsecase();
    });

final featureSetGoalPriorityUseCaseProvider =
    Provider<feature_goal_priority_set.SetGoalPriorityUsecase>((ref) {
      return feature_goal_priority_set.SetGoalPriorityUsecase(
        ref.read(domainGoalRepositoryProvider),
      );
    });

final featureUpdateGoalPriorityUseCaseProvider =
    Provider<feature_goal_priority_update.UpdateGoalPriorityUsecase>((ref) {
      return feature_goal_priority_update.UpdateGoalPriorityUsecase(
        ref.read(domainGoalRepositoryProvider),
      );
    });

final featureBackupGoalsUseCaseProvider =
    Provider<feature_goal_backup.BackupGoalsUsecase>((ref) {
      return feature_goal_backup.BackupGoalsUsecase(
        ref.read(domainGoalRepositoryProvider),
      );
    });

final featureExportGoalsUseCaseProvider =
    Provider<feature_goal_export.ExportGoalsUsecase>((ref) {
      return feature_goal_export.ExportGoalsUsecase(
        ref.read(domainGoalRepositoryProvider),
      );
    });

final featureImportGoalsUseCaseProvider =
    Provider<feature_goal_import.ImportGoalsUsecase>((ref) {
      return feature_goal_import.ImportGoalsUsecase(
        ref.read(domainGoalRepositoryProvider),
      );
    });

final featureRestoreGoalsUseCaseProvider =
    Provider<feature_goal_restore.RestoreGoalsUsecase>((ref) {
      return feature_goal_restore.RestoreGoalsUsecase(
        ref.read(domainGoalRepositoryProvider),
      );
    });

final featureLinkEmotionToGoalUseCaseProvider =
    Provider<feature_goal_link_emotion.LinkEmotionToGoalUsecase>((ref) {
      return feature_goal_link_emotion.LinkEmotionToGoalUsecase(
        ref.read(domainGoalRepositoryProvider),
        ref.read(domainTimelineRepositoryProvider),
      );
    });

final featureUnlinkEmotionFromGoalUseCaseProvider =
    Provider<feature_goal_unlink_emotion.UnlinkEmotionFromGoalUsecase>((ref) {
      return feature_goal_unlink_emotion.UnlinkEmotionFromGoalUsecase(
        ref.read(domainGoalRepositoryProvider),
        ref.read(domainTimelineRepositoryProvider),
      );
    });

final featureLinkHabitToGoalUseCaseProvider =
    Provider<feature_goal_link_habit.LinkHabitToGoalUsecase>((ref) {
      return feature_goal_link_habit.LinkHabitToGoalUsecase(
        ref.read(domainGoalRepositoryProvider),
        ref.read(domainTimelineRepositoryProvider),
      );
    });

final featureUnlinkHabitFromGoalUseCaseProvider =
    Provider<feature_goal_unlink_habit.UnlinkHabitFromGoalUsecase>((ref) {
      return feature_goal_unlink_habit.UnlinkHabitFromGoalUsecase(
        ref.read(domainGoalRepositoryProvider),
        ref.read(domainTimelineRepositoryProvider),
      );
    });

final featureLinkJournalEntryToGoalUseCaseProvider =
    Provider<feature_goal_link_journal.LinkJournalEntryToGoalUsecase>((ref) {
      return feature_goal_link_journal.LinkJournalEntryToGoalUsecase(
        ref.read(domainGoalRepositoryProvider),
        ref.read(domainTimelineRepositoryProvider),
      );
    });

final featureUnlinkJournalEntryFromGoalUseCaseProvider =
    Provider<feature_goal_unlink_journal.UnlinkJournalEntryFromGoalUsecase>((
      ref,
    ) {
      return feature_goal_unlink_journal.UnlinkJournalEntryFromGoalUsecase(
        ref.read(domainGoalRepositoryProvider),
        ref.read(domainTimelineRepositoryProvider),
      );
    });

final featureLinkFocusSessionToGoalUseCaseProvider =
    Provider<feature_goal_link_focus.LinkFocusSessionToGoalUsecase>((ref) {
      return feature_goal_link_focus.LinkFocusSessionToGoalUsecase(
        ref.read(domainGoalRepositoryProvider),
        ref.read(domainTimelineRepositoryProvider),
      );
    });

final featureUnlinkFocusSessionFromGoalUseCaseProvider =
    Provider<feature_goal_unlink_focus.UnlinkFocusSessionFromGoalUsecase>((
      ref,
    ) {
      return feature_goal_unlink_focus.UnlinkFocusSessionFromGoalUsecase(
        ref.read(domainGoalRepositoryProvider),
        ref.read(domainTimelineRepositoryProvider),
      );
    });

final featureArchiveGoalUseCaseProvider =
    Provider<feature_goal_archive.ArchiveGoalUsecase>((ref) {
      return feature_goal_archive.ArchiveGoalUsecase(
        ref.read(domainGoalRepositoryProvider),
        ref.read(domainTimelineRepositoryProvider),
      );
    });

final featureRestoreGoalMetadataUseCaseProvider =
    Provider<feature_goal_restore_metadata.RestoreGoalUsecase>((ref) {
      return feature_goal_restore_metadata.RestoreGoalUsecase(
        ref.read(domainGoalRepositoryProvider),
        ref.read(domainTimelineRepositoryProvider),
      );
    });

final featureFavoriteGoalUseCaseProvider =
    Provider<feature_goal_favorite.FavoriteGoalUsecase>((ref) {
      return feature_goal_favorite.FavoriteGoalUsecase(
        ref.read(domainGoalRepositoryProvider),
        ref.read(domainTimelineRepositoryProvider),
      );
    });

final featureUnfavoriteGoalUseCaseProvider =
    Provider<feature_goal_unfavorite.UnfavoriteGoalUsecase>((ref) {
      return feature_goal_unfavorite.UnfavoriteGoalUsecase(
        ref.read(domainGoalRepositoryProvider),
        ref.read(domainTimelineRepositoryProvider),
      );
    });

final featurePinGoalUseCaseProvider = Provider<feature_goal_pin.PinGoalUsecase>(
  (ref) {
    return feature_goal_pin.PinGoalUsecase(
      ref.read(domainGoalRepositoryProvider),
      ref.read(domainTimelineRepositoryProvider),
    );
  },
);

final featureUnpinGoalUseCaseProvider =
    Provider<feature_goal_unpin.UnpinGoalUsecase>((ref) {
      return feature_goal_unpin.UnpinGoalUsecase(
        ref.read(domainGoalRepositoryProvider),
        ref.read(domainTimelineRepositoryProvider),
      );
    });
