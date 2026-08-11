# Top-level root journeys

Version: `1.0.0`
Initial results: all `NOT RUN`

Each root case starts from a recorded known state and ends with a mandatory
visible assertion plus evidence. Test current surfaces only; no retired
Session/Focus, Journal, Logs, standalone Insights, or Smart Coach product
surface is introduced.

| Root | Required black-box journey | Mandatory end assertion |
|---|---|---|
| Nexus | Arrive after creation and lifecycle updates; refresh/relaunch. | Current state is coherent, actionable controls work, and no duplicate update appears. |
| Creator | Create and validate a task, goal, habit/routine and note; reject invalid input. | Each saved item remains attributable to Creator and is visible through its canonical projection. |
| Timeline | Verify items; complete, not-complete, skip and reschedule through available controls. | History/status/schedule matches the action and has no duplicate event. |
| Trajectory | View complete, limited, stale and conflicted-history fixtures where available. | Copy is a scenario/projection; it does not assert unsupported certainty. |
| Progression | Observe supported progress after canonical lifecycle action and retry. | One supported update occurs; repeated action does not duplicate XP/credit/reward. |
| Smart Planner | Request existing planning guidance in its existing flow. | It remains its own surface; no SI Console draft, memory view, navigation, or response leaks in. |
| SI Console | Use existing explanation/local-command flow. | It remains its own surface; it does not share Smart Planner request state or execute a direct mutation. |
| Profile | Inspect identity/session and execute assigned logout/login or deletion-boundary flow. | Account identity and persisted data are correct for the current user only. |
| Settings | Change/restore a non-destructive test setting; exercise permission/notification state. | State persists only as expected, and destructive controls require confirmation. |

For every applicable root, include empty, loading, partial/error/recovery and
offline observations when the persona/dataset can produce them. Accessibility
coverage is HR-A11Y-014 rather than a substitute root pass.
