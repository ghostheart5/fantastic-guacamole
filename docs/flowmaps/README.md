# FlowMaps

FlowMaps define how a feature actually runs from trigger to UI output.

## Core Definition
A FlowMap is an operational blueprint showing the exact route of an action through:
- UI screen
- Provider/controller
- Use case
- Repository
- Data source (Hive/Supabase/Firebase/etc.)
- System services (analytics, crash logging, notifications)
- Output, saved data, and fallback/error paths

## Standard Template
Use this structure for every feature FlowMap:

```text
Feature Name:
Trigger:
User Input:
Screen:
Provider/Controller:
Use Case:
Repository:
Data Source:
System Services:
Output:
Saved Data:
Errors:
Fallback:
Analytics Event:
```

## Build Pattern
Preferred ChronoSpark flow pattern:

```text
UI Screen
  -> Riverpod Provider/Controller
  -> Use Case
  -> Repository Interface
  -> Repository Implementation
  -> Data Source (Hive local / Supabase remote)
  -> Result
  -> Provider State Update
  -> UI Refresh
  -> Analytics + Error Logging
```

## Required System FlowMaps
1. Auth
2. Onboarding
3. Dashboard
4. Goals
5. Tasks
6. Habits
7. Streaks
8. Timeline
9. Milestones
10. Smart Coach
11. SI Console
12. Memory Engine
13. SoulMap
14. Offline Sync
15. Analytics
16. Error Handling
17. Subscription

## FlowMap Files
- analytics_flowmap.md
- auth_flowmap.md
- dashboard_flowmap.md
- error_handling_flowmap.md
- goals_flowmap.md
- habit_streak_flowmap.md
- habits_flowmap.md
- memory_engine_flowmap.md
- milestones_flowmap.md
- notification_flowmap.md
- offline_sync_flowmap.md
- onboarding_flowmap.md
- si_console_flowmap.md
- smart_coach_flowmap.md
- soulmap_flowmap.md
- streaks_flowmap.md
- subscription_flowmap.md
- tasks_flowmap.md
- timeline_flowmap.md

## Audit
- FLOWMAP_AUDIT.md tracks required-system coverage and pass/fail status.
