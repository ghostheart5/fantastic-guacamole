# Assistant controlled release

This runbook controls Smart Planner V2, SI Console V2, governed memory, and
the safety critic without changing their code or sharing state between them.

## Remote keys

| Key | Accepted value | Safe default |
|---|---|---|
| `assistant_release_stage` | `off`, `internal`, `opted_in_beta`, `canary`, `general` | `general` |
| `assistant_release_canary_basis_points` | integer from 0 through 10000 | `0` |
| `assistant_release_internal_account_digests` | comma-separated SHA-256 digests | empty |
| `assistant_shadow_evaluation_enabled` | boolean | `false` |
| `kill_assistant_smart_planner_v2` | boolean | `false` |
| `kill_assistant_si_console_v2` | boolean | `false` |
| `kill_assistant_governed_memory` | boolean | `false` |
| `kill_assistant_safety_critic` | boolean | `false` |

Unknown stages, out-of-range canary values, and malformed internal-account
digests fail closed. A critic rollback disables guarded assistant generation;
it never bypasses the critic.

## Promotion order

1. Enable shadow evaluation. Confirm that it receives only digests, counts,
   and finding codes and that both publication and write authority remain false.
2. Set the stage to `internal` and use only approved account digests.
3. Set the stage to `opted_in_beta`. Confirm that users who have not opted in
   remain excluded and that leaving beta removes eligibility.
4. Set the stage to `canary` and increase basis points in bounded steps.
   Account assignment is deterministic, so users do not move between buckets.
5. Set the stage to `general` only after the Phase 12 certification gate has
   passed for the required consecutive evidence windows.

## Independent rollback

1. Flip only the affected capability's `kill_...` key to `true`.
2. Refresh remote config and verify Settings reports `Emergency rollback active`.
3. Confirm the affected runtime is denied while the other three decisions stay
   enabled.
4. Keep crisis routing and delete/export controls available. Never turn off the
   safety critic by bypassing it; its rollback stops guarded generation.
5. Record the privacy-safe release receipt and the Phase 12 gate window that
   prompted rollback. Receipts contain account digests, never raw account IDs,
   prompts, responses, or chain-of-thought.
