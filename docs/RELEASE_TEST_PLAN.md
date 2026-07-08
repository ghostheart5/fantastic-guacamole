# Release Test Plan

This plan closes the highest-risk test gaps before production release.

## Scope

Areas covered:
- onboarding
- navigation
- task flow
- SI/chatbot
- persistence
- error states
- offline mode

## Current Baseline

- Unit test files: 18
- Integration test files: 5
- Dedicated widget test files under `test/`: none
- Snapshot line coverage from `coverage/lcov.info`: ~15.19%

## Release Gate

Before release, all P0 and P1 tests below should pass in CI.

- P0: required to ship
- P1: strongly recommended for first stable release
- P2: nice to have / hardening

## Test Cases By Layer

### Unit Tests (logic/state/services)

1. File: `test/onboarding/onboarding_controller_test.dart` (P1)
- start sets `OnboardingInProgress(step: 0)`
- nextStep advances and completes at last step
- previousStep does not underflow below 0
- reset returns to `OnboardingInitial`

2. File: `test/state/services/offline_sync_queue_service_test.dart` (P0)
- enqueue dedupes by `dedupeKey`
- replay increments attempts and sets `lastAttemptAtUtc`
- successful replay removes item
- failed replay keeps item
- replay respects `maxItems`
- malformed queue entries are ignored safely

3. File: `test/state/providers/sync_provider_test.dart` (P0)
- `syncToCloudProvider` enqueues `sync_to_cloud` on failure
- `syncToCloudProvider` replays queue before current sync
- `replayOfflineQueueProvider` returns processed count
- unknown queue action type returns false and remains queued

4. File: `test/app/navigation_shell_lifecycle_test.dart` (P1)
- pause/inactive triggers state save
- resume triggers recovery load
- recovered route maps to valid `AppView`

5. File: `test/data/services/ai/chat_agent_network_fallback_test.dart` (P1)
- non-200 proxy responses return null and fallback path is used
- timeout returns null without exception leak
- malformed JSON returns null safely

6. File: `test/ui/widgets/offline_banner_state_test.dart` (P1)
- online => hidden banner
- offline => visible banner text/icon

### Widget Tests (UI behavior in isolation)

1. File: `test/onboarding/onboarding_screen_test.dart` (P0)
- SKIP marks onboarding complete
- NEXT progresses pages and indicators
- personalization step writes name and goal type
- complete action updates `onboardingCompleteProvider`

2. File: `test/app/navigation_shell_test.dart` (P0)
- bottom nav tab changes screen index
- AppView switch renders correct route screen
- premium route gate appears for locked console
- offline banner appears when network state is offline

3. File: `test/features/tasks/task_screen_test.dart` (P0)
- empty state visible with no tasks
- render task list item from provider
- open task details and mark complete action path

4. File: `test/features/creator/creator_screen_test.dart` (P1)
- invalid form blocks create
- valid form triggers create action and clears input
- create error surfaces user-visible feedback

5. File: `test/features/home/smart_coach_screen_test.dart` (P1)
- send prompt triggers AI action
- failed AI response shows error/retry state
- credit exhausted state shows paywall prompt

6. File: `test/ui/widgets/error_boundary_widget_test.dart` (P1)
- child error renders fallback UI
- retry callback restores content path

### Integration Tests (cross-feature journeys)

1. File: `integration_test/onboarding_full_journey_integration_test.dart` (P0)
- complete entire onboarding flow across all pages
- persist and reload app -> onboarding is skipped
- personalization values are present after restart

2. File: `integration_test/navigation_recovery_integration_test.dart` (P0)
- navigate to non-default route
- simulate lifecycle pause/resume
- verify route restoration and stable render

3. File: `integration_test/task_crud_and_recurrence_integration_test.dart` (P0)
- create/edit/delete task from UI
- complete recurring task and verify next instance behavior
- verify persisted state after app restart

4. File: `integration_test/offline_sync_roundtrip_integration_test.dart` (P0)
- offline state shows banner
- sync action enqueues when cloud unavailable
- reconnect triggers queue replay
- queued item count returns to zero after success

5. File: `integration_test/chatbot_failure_recovery_integration_test.dart` (P1)
- proxy timeout/failure path shows safe fallback
- retry from UI succeeds after network recovers
- no duplicate assistant response after retry

6. File: `integration_test/error_state_surface_integration_test.dart` (P1)
- auth failure shows mapped error message
- paywall/credit exhaustion displays expected CTA
- sync failure surfaces non-blocking warning and recovery option

## Mapping To Requested Areas

- onboarding:
  - `test/onboarding/onboarding_controller_test.dart`
  - `test/onboarding/onboarding_screen_test.dart`
  - `integration_test/onboarding_full_journey_integration_test.dart`

- navigation:
  - `test/app/navigation_shell_test.dart`
  - `test/app/navigation_shell_lifecycle_test.dart`
  - `integration_test/navigation_recovery_integration_test.dart`

- task flow:
  - `test/features/tasks/task_screen_test.dart`
  - `test/features/creator/creator_screen_test.dart`
  - `integration_test/task_crud_and_recurrence_integration_test.dart`

- SI/chatbot:
  - `test/data/services/ai/chat_agent_network_fallback_test.dart`
  - `test/features/home/smart_coach_screen_test.dart`
  - `integration_test/chatbot_failure_recovery_integration_test.dart`

- persistence:
  - `test/state/services/offline_sync_queue_service_test.dart`
  - `test/state/providers/sync_provider_test.dart`
  - `integration_test/task_crud_and_recurrence_integration_test.dart`

- error states:
  - `test/ui/widgets/error_boundary_widget_test.dart`
  - `integration_test/error_state_surface_integration_test.dart`

- offline mode:
  - `test/ui/widgets/offline_banner_state_test.dart`
  - `test/state/services/offline_sync_queue_service_test.dart`
  - `integration_test/offline_sync_roundtrip_integration_test.dart`

## Suggested CI Rollout

1. Add all P0 unit/widget tests first and run on every PR.
2. Add P0 integration tests to a required nightly or release workflow.
3. Promote P1 integration tests to required before launch candidate tagging.
4. Track coverage trend and require net positive coverage deltas for P0/P1 files.

## Definition Of Done (Pre-Release)

- All P0 tests implemented and green in CI.
- P1 tests implemented for navigation recovery, chatbot failure, and error surfaces.
- No flaky failures across 3 consecutive CI runs.
- Release candidate build passes integration suite with offline + recovery scenarios.
