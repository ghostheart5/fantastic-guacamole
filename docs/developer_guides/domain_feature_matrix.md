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
| Tasks | task_entity.dart / task.dart | i_task_repository.dart | create/get/update/delete/complete/skip task | task_repository.dart | task_provider.dart | features/tasks/ui/task_screen.dart | Not verified here |
| Goals | goal_entity.dart | i_goal_repository.dart | create/get/update/delete/complete goal | goal_repository.dart | goals_provider.dart | features/goals/ui/goals_screen.dart | Usecase tests added |
| Flowmap | flowmap_node.dart | i_flowmap_repository.dart | get/update/delete flowmap node | flowmap_repository.dart | flowmap_provider.dart | features/flowmap/ui/flowmap_screen.dart | Usecase tests added |
| Memories | memory_entity.dart | i_memory_repository.dart | get/save/delete memory | memory_repository.dart | memories_provider.dart | features/memories/ui/memories_screen.dart | Usecase tests added |
| Timeline | timeline_event_entity.dart | i_timeline_repository.dart | get/add/remove timeline event | timeline_repository.dart | timeline_provider.dart | features/timeline/ui/timeline_screen.dart | Usecase tests added |
| Calendar | calendar_entry_entity.dart / calendar_entry.dart | i_calendar_repository.dart | get/add/remove calendar entry | calendar_repository.dart | calendar_provider.dart | feature wiring exists | Not verified here |
| Profile | profile_entity.dart | i_profile_repository.dart | get/update profile | profile_repository.dart | profile providers/controllers | feature wiring exists | Not verified here |
| Session | session_entity.dart | i_session_repository.dart | start/pause/resume/end/get session | session_repository.dart | session providers/controllers | feature wiring exists | Not verified here |
| Settings | settings_entity.dart | i_settings_repository.dart | get/update settings | settings_repository.dart | settings providers/controllers | settings UI exists | Not verified here |
| Workspace | workspace_entity.dart | i_workspace_repository.dart | get/switch workspace | workspace_repository.dart | workspace/service wiring exists | app shell uses it | Not verified here |
| Theme | app_theme_entity.dart | i_theme_repository.dart | get/save/get-all/switch theme | theme_repository.dart | theme_provider.dart | app_root.dart | Usecase tests added |
| Identity/Auth | identity_profile_entity.dart + identity id | i_identity_repository.dart | get/save identity profile | identity_repository.dart | identity_provider.dart + identity_service.dart | profile/insights + startup identity bootstrap | Usecase tests added |
| Insights | insight_entity.dart | i_insight_repository.dart | service-derived today | no data repo | insights_provider.dart | home surfaces use insights | Gap / likely derived |
| Learning | learning_entity.dart | i_learning_repository.dart | policy/usecases exist, data repo not added here | service-owned today | learning_controller.dart | indirect | Gap / explicit owner |
| Progression | progression_entity.dart | i_progression_repository.dart | get progression and task completion integration exist | service-owned today | progression_provider.dart | progression/timeline surfaces | Gap / explicit owner |

## Fast audit questions

1. Does the provider/controller call a usecase rather than a concrete repository?
2. Does the usecase depend on an interface?
3. Does the interface return domain entities?
4. Does the repository own persistence for that feature?
5. Is the UI insulated from repository/storage details?
6. Are tests present for entity policy and usecase behavior?
