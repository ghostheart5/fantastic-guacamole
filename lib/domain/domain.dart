// CHRONOSPARK-CLASS: SHIPPING | Feature: Domain public surface
// ChronoSpark domain barrel.
//
// READ THIS BEFORE "CLEANING UP" ANYTHING IN lib/domain.
//
// ChronoSpark has a deliberately large domain layer because the product is
// built around Smart Planner, SI Console, adaptive learning,
// progression, goals, workspace, calendar, subscriptions and automation.
// A file having no callers does NOT mean it is dead code — a lot of this is
// planned architecture that ships ahead of its UI.
//
// Every file under lib/domain carries a classification banner:
//
//     /// CHRONOSPARK-CLASS: <CLASS> | Feature: <feature>
//
// where <CLASS> is one of:
//   SHIPPING     — used by production behaviour. Must stay wired, tested,
//                  policy-gated and input-validated.
//   PLANNED      — intentionally kept for a ChronoSpark feature that is built
//                  or partially built but not yet surfaced in UI. Do not
//                  delete. Do not wire until the matching feature exists.
//   EXPERIMENTAL — exploratory. Keep, but never treat as shipping behaviour.
//   LEGACY       — older shape retained for compatibility/migration. Needs a
//                  migration plan, not a delete.
//   DEPRECATED   — no new call sites; retained so imports/migrations keep
//                  working.
//
// To audit: `rg "CHRONOSPARK-CLASS: PLANNED" lib/domain`
//
// This barrel exports only shipping surfaces. Planned, experimental, and
// deprecated code must be imported explicitly by the feature that owns it.

// Entities
export 'package:fantastic_guacamole/domain/entities/entitlement.dart';
export 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
export 'package:fantastic_guacamole/domain/entities/identity_profile_entity.dart';
export 'package:fantastic_guacamole/domain/entities/log_entry_entity.dart';
export 'package:fantastic_guacamole/domain/entities/memory_entity.dart';
export 'package:fantastic_guacamole/domain/entities/milestone_entity.dart';
export 'package:fantastic_guacamole/domain/entities/notification_entity.dart';
export 'package:fantastic_guacamole/domain/entities/paywall_entity.dart';
export 'package:fantastic_guacamole/domain/entities/paywall_plan.dart';
export 'package:fantastic_guacamole/domain/entities/plan_proposal_entity.dart';
export 'package:fantastic_guacamole/domain/entities/progression_entity.dart';
export 'package:fantastic_guacamole/domain/entities/project_entity.dart';
export 'package:fantastic_guacamole/domain/entities/si_decision_entity.dart';
export 'package:fantastic_guacamole/domain/entities/si_state_entity.dart';
export 'package:fantastic_guacamole/domain/entities/subscription_state.dart';
export 'package:fantastic_guacamole/domain/entities/subtask_entity.dart';
export 'package:fantastic_guacamole/domain/entities/task_entity.dart';
export 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
// Interfaces
export 'package:fantastic_guacamole/domain/interfaces/i_entitlement_repository.dart';
export 'package:fantastic_guacamole/domain/interfaces/i_goal_repository.dart';
export 'package:fantastic_guacamole/domain/interfaces/i_identity_repository.dart';
export 'package:fantastic_guacamole/domain/interfaces/i_signal_repository.dart';
export 'package:fantastic_guacamole/domain/interfaces/i_log_repository.dart';
export 'package:fantastic_guacamole/domain/interfaces/i_memory_repository.dart';
export 'package:fantastic_guacamole/domain/interfaces/i_milestone_repository.dart';
export 'package:fantastic_guacamole/domain/interfaces/i_note_repository.dart';
export 'package:fantastic_guacamole/domain/interfaces/i_notification_repository.dart';
export 'package:fantastic_guacamole/domain/interfaces/i_paywall_repository.dart';
export 'package:fantastic_guacamole/domain/interfaces/i_progression_repository.dart';
export 'package:fantastic_guacamole/domain/interfaces/i_si_repository.dart';
export 'package:fantastic_guacamole/domain/interfaces/i_subscription_repository.dart';
export 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
export 'package:fantastic_guacamole/domain/interfaces/i_theme_repository.dart';
export 'package:fantastic_guacamole/domain/interfaces/i_timeline_repository.dart';
// Policies
export 'package:fantastic_guacamole/domain/policies/notification_policy.dart';
export 'package:fantastic_guacamole/domain/policies/progression_policy.dart';
export 'package:fantastic_guacamole/domain/policies/si_policy.dart';
export 'package:fantastic_guacamole/domain/policies/task_policy.dart';
// Use cases
export 'package:fantastic_guacamole/domain/usecases/add_timeline_event.dart';
export 'package:fantastic_guacamole/domain/usecases/cancel_notification.dart';
export 'package:fantastic_guacamole/domain/usecases/complete_goal.dart';
export 'package:fantastic_guacamole/domain/usecases/complete_task.dart';
export 'package:fantastic_guacamole/domain/usecases/create_goal.dart';
export 'package:fantastic_guacamole/domain/usecases/create_task.dart';
export 'package:fantastic_guacamole/domain/usecases/delete_memory.dart';
export 'package:fantastic_guacamole/domain/usecases/generate_si_decision.dart';
export 'package:fantastic_guacamole/domain/usecases/get_all_themes.dart';
export 'package:fantastic_guacamole/domain/usecases/get_available_plans.dart';
export 'package:fantastic_guacamole/domain/usecases/get_current_theme.dart';
export 'package:fantastic_guacamole/domain/usecases/get_goals.dart';
export 'package:fantastic_guacamole/domain/usecases/get_identity_profile.dart';
export 'package:fantastic_guacamole/domain/usecases/get_memories.dart';
export 'package:fantastic_guacamole/domain/usecases/get_progress_signals.dart';
export 'package:fantastic_guacamole/domain/usecases/get_tasks.dart';
export 'package:fantastic_guacamole/domain/usecases/get_timeline_events.dart';
export 'package:fantastic_guacamole/domain/usecases/milestone_usecases.dart';
export 'package:fantastic_guacamole/domain/usecases/note_usecases.dart';
export 'package:fantastic_guacamole/domain/usecases/plan_proposal_usecases.dart';
export 'package:fantastic_guacamole/domain/usecases/remove_timeline_event.dart';
export 'package:fantastic_guacamole/domain/usecases/restore_purchases.dart';
export 'package:fantastic_guacamole/domain/usecases/save_planner_message.dart';
export 'package:fantastic_guacamole/domain/usecases/save_identity_profile.dart';
export 'package:fantastic_guacamole/domain/usecases/save_memory.dart';
export 'package:fantastic_guacamole/domain/usecases/save_theme.dart';
export 'package:fantastic_guacamole/domain/usecases/schedule_notification.dart';
export 'package:fantastic_guacamole/domain/usecases/start_subscription.dart';
export 'package:fantastic_guacamole/domain/usecases/switch_theme.dart';
export 'package:fantastic_guacamole/domain/usecases/update_goal.dart';
export 'package:fantastic_guacamole/domain/usecases/timeline_lifecycle_usecases.dart';
// Value objects
export 'entities/decision_outcome_entity.dart';
export 'interfaces/i_decision_outcome_repository.dart';
export 'usecases/decision_outcome_usecases.dart';
