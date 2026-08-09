# Storage RLS Execution Plan

Status: `READY_TO_RUN_PENDING_HUMAN_APPROVAL`. Do not execute without [STORAGE_VALIDATION_APPROVAL.md](STORAGE_VALIDATION_APPROVAL.md) completed and explicit approval.

All generated objects must be JSON files under `{user-uuid}/validation/{unique-run-id}/`. Do not access `{user-uuid}/backup/` paths.

| # | Test | Expected result | Cleanup requirement |
| --- | --- | --- | --- |
| 1 | User A uploads to User A path | Allowed. | User A generated object removed by its owner or approved runner cleanup. |
| 2 | User B uploads to User B path | Allowed. | User B generated object removed by its owner or approved runner cleanup. |
| 3 | User A uploads to User B path | Denied; no object created. | Verify no User B path mutation. |
| 4 | User B uploads to User A path | Denied; no object created. | Verify no User A path mutation. |
| 5 | Anonymous upload | Denied; no object created. | Verify no mutation. |
| 6 | User A reads User A file | Allowed; payload is the generated non-sensitive JSON. | Object remains only until planned cleanup. |
| 7 | User B reads User B file | Allowed; payload is the generated non-sensitive JSON. | Object remains only until planned cleanup. |
| 8 | User A reads User B file | Denied. | No cleanup beyond User B generated object. |
| 9 | User B reads User A file | Denied. | No cleanup beyond User A generated object. |
| 10 | Anonymous read | Denied. | No mutation expected. |
| 11 | User A deletes own validation object | Allowed. | Verify removal, then recreate a new User A validation object for cross-delete testing. |
| 12 | User B deletes own validation object | Allowed. | Verify removal, then recreate a new User B validation object for cross-delete testing. |
| 13 | User A deletes User B object | Denied; User B object remains. | User B object is removed only by User B or approved cleanup. |
| 14 | User B deletes User A object | Denied; User A object remains. | User A object is removed only by User A or approved cleanup. |
| 15 | Anonymous delete | Denied; owned validation objects remain. | Approved cleanup removes remaining generated objects. |

The guarded runner authenticates only normal User A/User B sessions and uses the anon key for anonymous calls. It prints a `PASS`/`FAIL`/`SKIP` summary, performs only generated-validation-object cleanup, and exits nonzero when a test or cleanup fails.
