# Onboarding FlowMap

## Trigger
New user session or replay onboarding action.

## Flow
1. App detects onboarding required state.
2. Onboarding screen loads content/version.
3. User advances, skips, or completes steps.
4. Provider persists step progress.
5. Tutorial analytics events are logged.
6. Completion updates onboarding state.
7. UI transitions to main app shell.

## Data and Services
- Screen: OnboardingScreen
- Provider/Controller: tutorial/onboarding provider
- Use case: save/reset/replay onboarding progress
- Repository: tutorial progress store
- Data source: local preferences/store
- Services: analytics

## Errors
- Progress save failure
- Corrupt stored onboarding state

## Fallback
- Rebuild onboarding state with defaults
- Continue UI with minimal blocking

## Analytics Event
- onboarding_started
- onboarding_step_completed
- onboarding_completed
