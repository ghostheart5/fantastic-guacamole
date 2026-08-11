# HR-INT-013: interruption and recovery

Version: `1.0.0`
Initial result: `NOT RUN`

Use an isolated account and run-scoped data. For each interruption, capture the
precondition, trigger, observable recovery condition, final state, screenshots,
recording and redacted logs. Never use arbitrary waiting as acceptance evidence.

| Interruption | Trigger | Mandatory recovery assertion |
|---|---|---|
| Background/foreground | Background during a non-destructive in-flight view, then resume. | No crash, duplicate save or unintended completion; visible state recovers. |
| Process kill | Kill the process after a confirmed save, then relaunch. | Confirmed state persists once; pending state is not falsely reported complete. |
| Device restart | Restart the test device after confirmed state. | Candidate launches and same-account state remains correct. |
| Rotation | Rotate during form, Timeline and dialog flows where supported. | Critical input/control remains usable; no duplicate submission. |
| Network loss | Disable network before an approved observable action. | Offline/error state is explicit and recovery does not duplicate work. |
| Slow network | Apply documented non-production latency/fault control. | Bounded loading/retry behavior; no false completion or duplicate persistence. |
| Time-zone change | Change test-device zone under documented fixture conditions. | Dates/schedules are not silently shifted beyond the product contract. |
| Clock change | Adjust device clock under documented fixture conditions. | No impossible ordering, duplicate progression or silent data corruption. |
| Denied permission | Deny a requested non-critical permission. | Primary path provides recovery/alternate state without crash or trap. |
| Low storage | Use an approved disposable device/storage condition. | Failure is recoverable, data is not silently lost, and cleanup is safe. |
| Repeated taps | Repeatedly tap a critical visible action under controlled conditions. | Only one intended item/event/credit/write is visible. |
| Account switch | Logout then authenticate User B after User A use. | User A data never appears for User B; no unauthorized carryover. |
| Expired token | Use an approved expiry fixture or wait/control in non-production. | Reauthentication is required where appropriate; protected data is not exposed. |

Any data loss, cross-user visibility, duplicate credit/payment, auth bypass,
crash loop, inaccessible recovery, or unauthorized Smart Planner/SI Console
connection is an automatic release veto.
