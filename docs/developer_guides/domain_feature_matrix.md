<style>
a {
    text-decoration: none;
    color: #464feb;
}
tr th, tr td {
    border: 1px solid #e6e6e6;
}
tr th {
    background-color: #f5f5f5;
}
</style>

## Domain feature matrix

Use this matrix to validate each feature chain:
Entity -> Interface -> Use cases -> Data implementation -> Provider -> UI screen -> Tests

| Feature | Entity | Interface | Use cases | Data implementation | Provider/controller | UI screen | Tests |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Tasks | task_entity.dart (`task.dart` is a compatibility adapter) | i_task_repository.dart | create/get/update/delete/complete/skip task | task_repository.dart | task_provider.dart | Creator creates tasks; Timeline presents scheduled task activity | Entity mapping and usecase tests |
| Goals | goal_entity.dart | i_goal_repository.dart | create/get/update/delete/complete goal | goal_repository.dart | goals_provider.dart | features/goals/ui/goals_screen.dart | Usecase tests added |
| Memories | memory_entity.dart | i_memory_repository.dart | get/save/delete memory | memory_repository.dart | memories_provider.dart | Smart Planner, SI, and Nexus consume memory context; no standalone screen | Usecase tests added |
| Notes | note_entity.dart | i_note_repository.dart | get/create/update/archive/delete note | note_repository.dart | notes_provider.dart | Creator and current planning surfaces consume notes; no standalone screen | Usecase tests added |
| Milestones | milestone_entity.dart | i_milestone_repository.dart | get/create/update/progress/complete/archive/delete milestone | milestone_repository.dart | milestones_provider.dart | Nexus and Timeline consume milestones; no standalone screen | Usecase tests added |
| Timeline | timeline_event_entity.dart | i_timeline_repository.dart | query range/schedule/reschedule/complete/skip/recover event | timeline_repository.dart | timeline_provider.dart | features/timeline/ui/timeline_screen.dart | Lifecycle usecase tests |
| Plans | plan_entity.dart / plan_proposal_entity.dart | i_plan_repository.dart | create/get/update plan plus preview/apply/reject proposal | plan_repository.dart | adaptive_plan_provider.dart | Smart Planner previews proposals; accepted blocks appear on Timeline | Proposal lifecycle tests |
| Calendar | calendar_entry_entity.dart (`calendar_entry.dart` is an alias; `time_block.dart` is a planner adapter) | i_calendar_repository.dart | get/add/remove calendar entry | calendar_repository.dart | calendar_provider.dart | Calendar data feeds planning surfaces | Entity mapping tests |
| Habits/routines | habit_entity.dart (`habit_record.dart` and `routine_entity.dart` are aliases) | i_habit_repository.dart / i_routine_repository.dart | get/create/update/toggle/delete/save habits and routines | habit_repository.dart / routine_repository.dart | habits_provider.dart / routines_provider.dart | Current planning and SI surfaces consume daily rhythms; no standalone screen | Usecase tests |
| Profile | profile_entity.dart | i_profile_repository.dart | get/update profile | profile_repository.dart | profile providers/controllers | feature wiring exists | Not verified here |
| Settings | settings_entity.dart | i_settings_repository.dart | get/update settings | settings_repository.dart | settings providers/controllers | settings UI exists | Not verified here |
| Workspace | workspace_entity.dart | i_workspace_repository.dart | get/switch workspace | workspace_repository.dart | workspace/service wiring exists | app shell uses it | Not verified here |
| Theme | app_theme_entity.dart | i_theme_repository.dart | get/save/get-all/switch theme | theme_repository.dart | theme_provider.dart | app_root.dart | Usecase tests added |
| Identity/Auth | identity_profile_entity.dart + identity id | i_identity_repository.dart | get/save identity profile | identity_repository.dart | identity_provider.dart + identity_service.dart | profile + startup identity bootstrap | Usecase tests added |
| Signal outputs | signal_entity.dart | i_signal_repository.dart | generate/get/save derived outputs | signal_repository.dart | signals_provider.dart | Smart Planner, SI Console, and Nexus consume outputs; no standalone screen | Output pipeline, not a feature |
| Learning | learning_entity.dart | i_learning_repository.dart | policy/usecases exist, data repo not added here | service-owned today | learning_controller.dart | indirect | Gap / explicit owner |
| Progression | progression_entity.dart | i_progression_repository.dart | get progression and task completion integration exist | service-owned today | progression_provider.dart | progression/timeline surfaces | Gap / explicit owner |
| Recommendation feedback | decision_outcome_entity.dart | i_decision_outcome_repository.dart | get/record decision outcome | decision_outcome_repository.dart | decision_outcome_provider.dart | Nexus and planner surfaces record shown/accepted/rejected/corrected/completed/deferred outcomes | Repository and usecase tests |

## Fast audit questions

1. Does the provider/controller call a usecase rather than a concrete repository?
2. Does the usecase depend on an interface?
3. Does the interface return domain entities?
4. Does the repository own persistence for that feature?
5. Is the UI insulated from repository/storage details?
6. Are tests present for entity policy and usecase behavior?
