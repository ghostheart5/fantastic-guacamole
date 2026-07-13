# ChronoSpark Analytics Event Taxonomy

> **LOCKED for closed testing window.**  
> Do not rename, remove, or add events without updating this document and bumping the schema version.
>
> **Schema version:** 1.0  
> **Locked date:** 2026-07-13

---

## Naming Conventions

- Event names: `snake_case`, maximum 40 characters
- Parameter names: `snake_case`, maximum 40 characters
- Parameter values: strings truncated to 100 characters; numerics as `double`
- Prefix feature events with the feature slug: `task_`, `coach_`, `focus_`, `si_`, `paywall_`, `auth_`, `onboarding_`
- System lifecycle events have no prefix: `app_open`, `session_start`, `session_end`

---

## System Lifecycle Events

| Event | Parameters | Description |
|-------|-----------|-------------|
| `app_open` | `flavor: string`, `version: string` | App brought to foreground |
| `session_start` | `flavor: string` | New session begins |
| `session_end` | `duration_seconds: double` | Session ends (app background/close) |

---

## Auth Events

| Event | Parameters | Description |
|-------|-----------|-------------|
| `auth_signup_started` | `method: string` | User begins sign-up (email, google, github) |
| `auth_signup_completed` | `method: string` | Sign-up flow completed successfully |
| `auth_signup_failed` | `method: string`, `error_code: string` | Sign-up failed |
| `auth_login_started` | `method: string` | User begins login |
| `auth_login_completed` | `method: string` | Login successful |
| `auth_login_failed` | `method: string`, `error_code: string` | Login failed |
| `auth_logout` | – | User explicitly logs out |
| `auth_mock_login` | – | Tester mock login used (QA builds only) |

---

## Onboarding Events

| Event | Parameters | Description |
|-------|-----------|-------------|
| `onboarding_started` | – | First-run tutorial begins |
| `onboarding_step_completed` | `step: string`, `step_index: int` | Individual onboarding step completed |
| `onboarding_completed` | `duration_seconds: double` | Full onboarding flow finished |
| `onboarding_skipped` | `at_step: string` | User skipped onboarding |
| `tutorial_shown` | `context_id: string` | Contextual tutorial hint displayed |
| `tutorial_dismissed` | `context_id: string` | Contextual tutorial hint dismissed |

---

## Task Events

| Event | Parameters | Description |
|-------|-----------|-------------|
| `task_created` | `priority: string`, `has_deadline: bool` | Task created |
| `task_edited` | – | Task updated |
| `task_completed` | `duration_days: double`, `priority: string` | Task marked complete |
| `task_deleted` | – | Task deleted |
| `task_skipped` | – | Task skipped |
| `task_session_started` | `task_id_hash: string` | Focus session started on a task |

---

## Focus Session Events

| Event | Parameters | Description |
|-------|-----------|-------------|
| `focus_session_started` | `duration_minutes: int` | Focus session began |
| `focus_session_completed` | `duration_minutes: int`, `xp_earned: double` | Session completed |
| `focus_session_paused` | `elapsed_seconds: double` | Session paused |
| `focus_session_resumed` | – | Session resumed from pause |
| `focus_session_cancelled` | `elapsed_seconds: double` | Session cancelled |

---

## Smart Coach Events

| Event | Parameters | Description |
|-------|-----------|-------------|
| `coach_opened` | – | Smart Coach screen opened |
| `coach_query_sent` | `intent: string` | User sends a query |
| `coach_response_received` | `latency_ms: double`, `intent: string` | Response rendered |
| `coach_fallback_shown` | `reason: string` | Fallback response shown |

---

## SI Console Events

| Event | Parameters | Description |
|-------|-----------|-------------|
| `si_console_opened` | – | SI Console opened |
| `si_query_sent` | `query_length: int` | Query submitted to SI engine |
| `si_response_received` | `latency_ms: double` | SI response rendered |
| `si_trial_consumed` | `feature: string`, `remaining: int` | SI trial use consumed |
| `si_trial_exhausted` | `feature: string` | SI trial completely exhausted |

---

## Paywall / Subscription Events

| Event | Parameters | Description |
|-------|-----------|-------------|
| `paywall_shown` | `source: string`, `tier: string` | Paywall screen shown |
| `paywall_dismissed` | `source: string` | User dismissed paywall |
| `paywall_purchase_started` | `product_id: string`, `tier: string` | Purchase flow initiated |
| `paywall_purchase_completed` | `product_id: string`, `tier: string` | Purchase successful |
| `paywall_purchase_failed` | `product_id: string`, `error_code: string` | Purchase failed |
| `paywall_restore_started` | – | Restore purchases initiated |
| `paywall_restore_completed` | `restored_count: int` | Restore completed |
| `paywall_restore_failed` | `error_code: string` | Restore failed |

---

## Error Events

| Event | Parameters | Description |
|-------|-----------|-------------|
| `error_boundary_triggered` | `screen: string`, `error_type: string` | Error boundary caught unhandled error |
| `sync_failed` | `reason: string`, `retry_count: int` | Cloud sync operation failed |
| `offline_mode_entered` | – | App detected network loss |
| `offline_mode_exited` | – | Network restored |

---

## Dashboard / Analytics Integration

All events listed above should be sent via the `AppAnalytics.track()` method.  
Events must not contain PII (no email addresses, display names, or user-generated content as parameter values).  
Use hashed IDs where entity identity is required (e.g., `task_id_hash`).

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 1.0 | 2026-07-13 | Initial taxonomy lock for closed testing |
