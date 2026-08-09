# Storage Policy Implementation Review

Status: local implementation review only. It does not confirm the effective hosted staging policy.

## Bucket

| Bucket | Intended visibility | Source |
| --- | --- | --- |
| `chronospark-sync` | Private (`public = false`) | `supabase/migrations/202607110002_data_policies.sql` |

## Ownership mechanism

Access is based on all of the following:

1. The caller must have the `authenticated` role.
2. `storage.objects.bucket_id` must equal `chronospark-sync`.
3. `split_part(storage.objects.name, '/', 1)` must equal `auth.uid()::text`.

It is not based on the Storage object owner column. The top-level path prefix is the authorization boundary.

## Policies

| Policy | Purpose | Permission | Ownership predicate |
| --- | --- | --- | --- |
| `chronospark_sync_select_own` | Read an owned backup or validation object. | `SELECT` | Bucket equals `chronospark-sync` and first path segment equals `auth.uid()`. |
| `chronospark_sync_insert_own` | Create an owned object. | `INSERT` | Bucket equals `chronospark-sync` and first path segment equals `auth.uid()`. |
| `chronospark_sync_update_own` | Replace an owned object. | `UPDATE` | Both `USING` and `WITH CHECK` require the bucket and first path segment to match `auth.uid()`. |
| `chronospark_sync_delete_own` | Remove an owned object. | `DELETE` | Bucket equals `chronospark-sync` and first path segment equals `auth.uid()`. |

## Expected behavior

- Upload: an authenticated user can create or upsert only under `{auth.uid()}/...`.
- Read: an authenticated user can read only under `{auth.uid()}/...`.
- Delete: an authenticated user can delete only under `{auth.uid()}/...`.
- Cross-user access: denied because the first path component differs from the caller UUID.
- Anonymous access: denied. The bucket is private and every declared object policy is `to authenticated`.

## Runtime alignment

The runtime backup paths are `{uid}/backup/full_backup.json` and `{uid}/backup/tasks_backup.json`. The guarded validation runner uses only `{uid}/validation/...`, never `/backup/`.

## Limitation

This review establishes repository intent, not effective hosted policy. Execution remains `READY_TO_RUN_PENDING_HUMAN_APPROVAL` until the bucket and policy contract are confirmed in staging.
