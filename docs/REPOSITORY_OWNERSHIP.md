# Repository Ownership Matrix

This document resolves repository/interface mismatch by declaring explicit ownership for each domain repository interface.

Policy:
- Preferred: interface implemented under `lib/data/repositories/*`.
- Allowed exception: if intentionally state/app-owned, it must be listed here and validated by `check_architecture.ps1`.

## Implemented In Data Repositories

| Interface | Concrete implementation(s) |
|---|---|
| `ITaskRepository` | `lib/data/repositories/task_repository.dart` |
| `INotificationRepository` | `lib/data/repositories/notifications_repository.dart` |
| `ILogRepository` | `lib/data/repositories/log_repository.dart` |
| `ICalendarRepository` | `lib/data/repositories/calendar_repository.dart` |
| `IProfileRepository` | `lib/data/repositories/profile_repository.dart` |
| `ISettingsRepository` | `lib/data/repositories/settings_repository.dart` |
| `ISessionRepository` | `lib/data/repositories/session_repository.dart` |
| `IWorkspaceRepository` | `lib/data/repositories/workspace_repository.dart` |
| `IPaywallRepository` | `lib/data/repositories/paywall_repository.dart`, `lib/data/repositories/google_play_paywall_repository.dart` |
| `ISiRepository` | `lib/state/providers/domain_usecase_providers.dart` (`_SiRepositoryAdapter`) |

## Explicit Non-Data Owners

| Interface | Owner | Notes |
|---|---|---|
| `IInsightRepository` | `lib/state/services/insights_service.dart` | Insights are generated in application orchestration layer. |
| `ILearningRepository` | `lib/state/services/intelligence_service.dart` | Learning logic currently sits in state orchestration. |
| `IProgressionRepository` | `lib/state/services/progression_service.dart` | Progression transformation is service-owned today. |
| `IThemeRepository` | `lib/state/services/theme_service.dart` | Theme orchestration depends on `IThemeRepository` contract. |

## Guardrail

Run the architecture guardrail task:

- VS Code task: `check-architecture`
- Script: `check_architecture.ps1`

The checker fails if a domain repository interface has neither:
- a concrete implementation via `implements I*Repository`, nor
- an explicit owner listed in the checker mapping.
