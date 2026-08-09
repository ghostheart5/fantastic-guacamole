# MAESTRO COVERAGE REPORT

Date: 2026-08-03
Project: ChronoSpark Smart Planner (Flutter)

## Covered Screens

1. Onboarding
2. Login/Auth surface
3. Nexus/Home shell
4. Creator
5. Timeline
6. Profile
7. Settings
8. Notifications
9. Paywall
10. Subscription Management
11. Smart Planner
12. SI Console

## Covered Flows

1. Smoke launch and no-startup-crash checks
2. Onboarding walkthrough and skip path
3. Login and logout path
4. Navigation shell transitions
5. Creator add item paths (task, goal, note, habit-style recurrence)
6. Timeline load, filters, search, scroll, completed-state checks
7. Smart Planner prompt input classes and response visibility
8. SI Console command and edge input checks
9. Settings persistence checks after restart
10. Monetization gate and paywall route checks

## Covered Monetization Paths

1. Free-user redirection to paywall
2. Plan list visibility and select CTA presence
3. Subscription management view visibility
4. Premium route protection probe

## Covered AI Paths

1. Smart Planner simple/complex/special/long prompts
2. Smart Planner empty input guard
3. SI Console open, input, and roundtrip output visibility
4. SI Console edge payload handling

## Covered Settings

1. Dark mode toggle persistence check
2. Audio effects toggle path
3. Haptic feedback toggle path
4. Reflection reminder toggle path
5. Daily planning reminder automation path
6. Notification recovery route entry

## Missing Coverage

1. Real store purchase completion and real restore transactions (requires sandbox stores and account fixtures)
2. Full network partition chaos testing (airplane mode orchestration not deterministic in local Maestro only)
3. Deep link full matrix from external app launch intent entry
4. Provider-level diagnostics assertions beyond UI signal checks

## High Risk Areas

1. Activation funnel routing and redirect loops
2. Smart Planner timeout and error UX consistency
3. Session restoration after forced relaunch
4. Monetization protection drift on premium-only routes
5. Settings persistence across relaunch for all toggles

## Suggested Next Iteration

1. Add explicit test keys in UI for deterministic selector stability
2. Add dedicated deep-link launch test harness
3. Add store sandbox purchase and restore jobs in CI matrix
