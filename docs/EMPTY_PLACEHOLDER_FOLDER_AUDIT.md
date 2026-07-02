# Empty Files, Placeholder Files, and Empty Folders Audit

Generated: 2026-06-27

## Scope
- Scan mode: recursive workspace scan.
- Intent: inventory only (no fixes).
- Notes: generated folders can appear/disappear during builds; this report reflects current state at scan time.

## Summary
- Empty files: 0
- Placeholder files (name contains `placeholder`): 65
- Stub files (name contains `stub`): 1
- Empty folders: 3

## Empty Files
- None found.

## Placeholder Files
- features/tasks/services/placeholder_service.dart
- features/tasks/models/placeholder_model.dart
- features/creator/logic/placeholder_logic.dart
- features/tasks/logic/placeholder_logic.dart
- features/creator/services/placeholder_service.dart
- features/nexus/logic/placeholder_logic.dart
- features/creator/models/placeholder_model.dart
- lib/features/tasks/services/tasks_services_placeholder.dart
- lib/features/tasks/models/tasks_models_placeholder.dart
- lib/features/tasks/logic/tasks_logic_placeholder.dart
- features/coach/services/placeholder_service.dart
- features/coach/models/placeholder_model.dart
- features/coach/logic/placeholder_logic.dart
- features/logs/services/placeholder_service.dart
- features/auth/services/placeholder_service.dart
- features/home/models/placeholder_model.dart
- features/logs/models/placeholder_model.dart
- features/home/logic/placeholder_logic.dart
- features/auth/models/placeholder_model.dart
- lib/features/settings/screens/settings_screens_placeholder.dart
- features/logs/logic/placeholder_logic.dart
- features/home/services/placeholder_service.dart
- features/auth/logic/placeholder_logic.dart
- features/nexus/services/placeholder_service.dart
- features/focus/services/placeholder_service.dart
- features/nexus/models/placeholder_model.dart
- features/focus/models/placeholder_model.dart
- features/insights/logic/placeholder_logic.dart
- features/insights/models/placeholder_model.dart
- features/insights/services/placeholder_service.dart
- features/focus/logic/placeholder_logic.dart
- lib/features/focus/state/focus_state_placeholder.dart
- lib/features/logs/state/logs_state_placeholder.dart
- lib/features/focus/services/focus_services_placeholder.dart
- lib/features/logs/services/logs_services_placeholder.dart
- features/reflect/services/placeholder_service.dart
- features/profile/services/placeholder_service.dart
- features/reflect/models/placeholder_model.dart
- features/profile/models/placeholder_model.dart
- features/reflect/logic/placeholder_logic.dart
- lib/features/progression/state/progression_state_placeholder.dart
- features/profile/logic/placeholder_logic.dart
- features/si_console/logic/placeholder_logic.dart
- features/progression/services/placeholder_service.dart
- features/progression/logic/placeholder_logic.dart
- features/progression/models/placeholder_model.dart
- features/si_console/models/placeholder_model.dart
- lib/features/profile/state/profile_state_placeholder.dart
- lib/features/insights/ui/insights_ui_placeholder.dart
- features/plan/services/placeholder_service.dart
- features/plan/logic/placeholder_logic.dart
- features/settings/logic/placeholder_logic.dart
- features/settings/services/placeholder_service.dart
- features/settings/models/placeholder_model.dart
- features/si_console/services/placeholder_service.dart
- features/plan/models/placeholder_model.dart
- lib/features/insights/state/insights_state_placeholder.dart
- lib/features/insights/services/insights_services_placeholder.dart
- features/notifications/models/placeholder_model.dart
- features/notifications/services/placeholder_service.dart
- lib/features/insights/models/insights_models_placeholder.dart
- lib/features/insights/logic/insights_logic_placeholder.dart
- features/notifications/logic/placeholder_logic.dart
- docs/EMPTY_PLACEHOLDER_FOLDER_AUDIT.md
- docs/audit_empty_placeholder_report.md

## Stub Files
- scripts/receipt_verifier_stub.js

## Empty Folders
- android/.kotlin/sessions
- ios/Flutter/ephemeral/Packages/.packages
- macos/Flutter/ephemeral/Packages/.packages

## Notes
- Placeholder classes were specifically confirmed in focus state/services:
	- lib/features/focus/state/focus_state_placeholder.dart
	- lib/features/focus/services/focus_services_placeholder.dart
- If you want, next step can be a grouped replacement plan by feature (focus, insights, logs, tasks, etc.) without changing runtime logic.
