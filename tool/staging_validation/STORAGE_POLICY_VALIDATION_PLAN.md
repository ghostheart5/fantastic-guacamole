# Storage Policy Validation Plan

Status: planning only. `STORAGE_VALIDATION_REQUIRED`.

Do not run this plan until an approved staging bucket/path policy contract and generated-object cleanup owner exist. This plan authorizes no bucket creation, upload, download, delete, SQL, deployment, or production activity.

## Preconditions

- Confirm staging has the intended private `chronospark-sync` bucket.
- Confirm effective `storage.objects` policies match the repository intent: authenticated users may select/insert/update/delete only when the first object-path segment equals `auth.uid()`.
- Use two ordinary authenticated staging users, User A and User B. Do not use service-role credentials in client scripts.
- Reserve a unique disposable test prefix: `{user-id}/validation/{scenario-id}/...`.
- Name the approved cleanup owner for generated objects before the first write.

## User A upload

| Item | Plan |
| --- | --- |
| Path | `UserA/validation/{scenario-id}/owned.json` |
| Action | User A uploads a small JSON object using normal authenticated client credentials. |
| Expected behavior | Allowed by authenticated insert-own policy. |
| Evidence | HTTP/result category, redacted path, timestamp, User A label, and generated-object cleanup record. |
| Cleanup | Approved owner removes only the generated test object after evidence review. |

## User A read

| Item | Plan |
| --- | --- |
| Path | User A's generated object under `UserA/validation/...`. |
| Action | User A downloads the object with normal authenticated client credentials. |
| Expected behavior | Allowed by authenticated select-own policy; content matches the generated non-sensitive payload. |
| Evidence | Result category, redacted path, payload checksum or non-sensitive nonce, timestamp. |

## User B denied access

| Item | Plan |
| --- | --- |
| Path | The User A test object. |
| Action | User B attempts normal-client read/list access against the User A path. |
| Expected behavior | Denied because the first path segment is not User B's `auth.uid()`. |
| Evidence | Denial status/category and redacted paths; do not capture credentials or object content. |
| Cleanup | None, provided no object was created or changed. |

## User B denied delete

| Item | Plan |
| --- | --- |
| Path | The User A test object. |
| Action | User B attempts normal-client `remove` against the User A path. |
| Expected behavior | Denied by delete-own policy; User A object remains readable by User A. |
| Evidence | Denial status/category plus User A follow-up existence/read evidence. |
| Cleanup | Approved owner later removes the User A generated object. |

## Anonymous expected behavior

| Item | Plan |
| --- | --- |
| Target | Bucket listing, owned-path read, upload, and delete attempts without an authenticated session. |
| Expected behavior | Denied. The bucket is intended private and all declared object policies are `to authenticated`. |
| Evidence | Denial status/category only; no credentials, raw headers, or sensitive paths in reports. |
| Cleanup | None, provided all operations are denied. |

## Acceptance criteria

- User A can upload and read only the generated object in User A's owned path.
- User B cannot read, list, alter, or delete User A's test object.
- Anonymous requests are denied.
- The approved cleanup owner removes only generated validation objects and verifies their absence.
- Any mismatch between effective staging behavior and repository policy blocks release until reviewed.

## Release classification

`STORAGE_VALIDATION_REQUIRED`: active cloud backup code references Supabase Storage. Storage cannot be marked out of the release path.
