# TEST PRIORITY 2 - High Value Regression Paths

Date: 2026-08-03
Project: ChronoSpark Smart Planner (Flutter)

## Scope
Priority 2 covers high-value user journeys and resilience checks that are not always release-blocking but strongly affect retention and support cost.

## Included Domains

1. Timeline filtering, search, and scrolling behavior
2. Smart Planner prompt variants and rendering behavior
3. SI Console interaction quality and command flow
4. Settings persistence for reminder and automation preferences
5. Notifications open/read/delete visual paths
6. Profile and billing center discoverability

## P2 Risk Matrix

1. Medium: stale state after background and relaunch
2. Medium: incomplete rendering under long text AI responses
3. Medium: timeline filters produce unexpected empty states
4. Medium: settings changes silently fail persistence
5. Medium: notification recovery entry point inaccessible

## P2 Test Inventory (Nightly)

1. maestro/timeline/timeline_filters.yaml
2. maestro/timeline/timeline_scroll.yaml
3. maestro/timeline/timeline_completed_items.yaml
4. maestro/smart_planner/prompt_complex.yaml
5. maestro/smart_planner/prompt_special_characters.yaml
6. maestro/smart_planner/prompt_long.yaml
7. maestro/si_console/si_console_command_roundtrip.yaml
8. maestro/si_console/si_console_edge_input.yaml
9. maestro/settings/settings_reminder_persistence_restart.yaml
10. maestro/notifications/_suite_notifications.yaml
11. maestro/profile/profile_billing_access.yaml

## Exit Criteria

1. No recurring failures across two consecutive nightly runs
2. No persistence regressions in settings-focused flows
3. No AI-surface rendering failures for long or complex input
