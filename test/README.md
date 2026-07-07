# Test Layout

This folder follows a layer-first testing layout.

## Helpers

- helpers/fake_task_repository.dart
- helpers/fake_calendar_repository.dart
- helpers/fake_si_repository.dart
- helpers/fake_storage.dart
- helpers/provider_container.dart
- helpers/test_entities.dart

## Layer Folders

- domain/entities
- domain/value_objects
- domain/policies
- domain/usecases
- data/repositories
- data/storage
- data/local
- data/services
- state/controllers
- state/providers
- engine/si
- engine/learning
- engine/planning
- engine/scoring
- engine/tasks
- features/tasks
- features/si_console
- features/home
- features/plan
- features/logs
- features/settings

## Integration Release-Critical Flows

Treat these as the core release gate flows:

- integration_test/app_startup_test.dart
- integration_test/task_lifecycle_test.dart
- integration_test/persistence_recovery_test.dart
- integration_test/si_console_flow_test.dart
- integration_test/paywall_gate_test.dart

## Priority 20 Status

- [x] create_task_test.dart - valid task creates
- [x] create_task_test.dart - empty title fails
- [x] complete_task_test.dart - incomplete task completes
- [x] complete_task_test.dart - already completed task does not double-count
- [x] skip_task_test.dart - skipped task updates learning signal
- [x] update_task_test.dart - preserves ID and updates fields
- [x] delete_task_test.dart - missing ID returns safe failure behavior
- [x] task_repository_test.dart - create/read roundtrip
- [x] storage_migration_test.dart - old schema migrates
- [x] storage_migration_test.dart - malformed snapshot fallback
- [x] state/services/session_recovery_service_test.dart - interrupted session restores
- [x] calendar_policy_test.dart - overlapping time blocks rejected
- [x] notification_policy_test.dart - cooldown prevents spam
- [x] generate_si_decision_test.dart - empty task list fallback
- [x] generate_si_decision_test.dart - urgent task ranked first
- [x] engine/si/si_engine_service_test.dart - does not accept repeated output
- [x] data/services/ai/agent_orchestrator_test.dart - malformed command returns safe normalized result
- [x] task_provider_test.dart - repository failure becomes error state
- [x] si_console_screen_test.dart - invalid input displays safe fallback
- [x] integration_test/task_lifecycle_test.dart - create -> complete -> state update
