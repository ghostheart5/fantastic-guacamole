# TEST PRIORITY 1 - Release Blocking Paths

Date: 2026-08-03
Project: ChronoSpark Smart Planner (Flutter)
Owner: Mobile QA and Maestro Automation

## Scope
Priority 1 covers release-blocking user paths, revenue gates, and flows that can cause immediate churn, data loss, or app rejection.

## Critical User Paths

1. Launch -> onboarding gate -> authentication gate -> creator gate -> timeline gate -> home
2. Launch (returning user) -> session restore -> home visible
3. Home -> navigation map -> creator/timeline/profile/settings transitions
4. Profile -> logout -> login screen

## Revenue Paths (Must Pass)

1. Premium-gated route access redirects to paywall for free users
2. Paywall loads plans and select CTA is visible
3. Subscription management route opens and entitlement state renders

## High-Risk Crash Paths

1. Smart Planner request path timeout or malformed input handling
2. SI Console high-frequency prompt input and command dispatch
3. Creator submit with empty title and rapid re-submit
4. Timeline item action sheet actions (complete, skip, reschedule)

## Navigation Failures to Detect

1. Redirect loops between onboarding, login, and creator
2. Locked activation states preventing expected transitions
3. Back navigation trapping users in nested surfaces

## State Persistence Failures to Detect

1. Session state not restored after relaunch
2. Settings toggles not persisted after restart
3. Onboarding completion not respected after relaunch

## Authentication Risks

1. Login route and onboarding interplay edge cases
2. Sign-out not fully clearing active session UX
3. Expired session handling and login fallback

## Deep Link Risks

1. Deep link to premium surfaces without entitlement
2. Auth callback mode handling and gate bypass edges
3. Invalid route fallback behavior

## Data Loss Risks

1. Creator draft loss in interrupted entry
2. Timeline-first-action flag not persisted after first exposure
3. Follow-up AI conversation state lost on relaunch

## P1 Test Inventory (Must Run Per Commit)

1. maestro/smoke/_suite_smoke.yaml
2. maestro/onboarding/_suite_onboarding.yaml
3. maestro/authentication/_suite_authentication.yaml
4. maestro/timeline/_suite_timeline.yaml
5. maestro/planner/_suite_planner.yaml
6. maestro/smart_planner/_suite_smart_planner.yaml
7. maestro/si_console/_suite_si_console.yaml
8. maestro/subscriptions/_suite_subscriptions.yaml
9. maestro/settings/settings_persistence_restart.yaml
10. maestro/release/release_full_validation.yaml

## Exit Criteria

1. Zero critical flow failures
2. Zero navigation dead-ends in activation funnel
3. Zero smoke regressions
4. Monetization gate behavior verified for free users
