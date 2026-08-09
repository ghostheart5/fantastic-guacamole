# Storage Test Cleanup Contract

Status: cleanup execution is not approved until [STORAGE_VALIDATION_APPROVAL.md](STORAGE_VALIDATION_APPROVAL.md) is completed.

## Allowed validation objects

- Bucket: `chronospark-sync` only.
- Prefix: `{UserAUuid}/validation/{unique-run-id}/` and `{UserBUuid}/validation/{unique-run-id}/` only.
- File type: generated non-sensitive JSON validation payloads only.
- The runner must reject a path containing `/backup/`, a path outside the caller UUID prefix, or a path outside `/validation/`.

## Prohibited objects

- `backup/full_backup.json` and `backup/tasks_backup.json`.
- Any existing user object, media, receipt evidence, credentials, service-role material, or production object.
- Any bucket other than `chronospark-sync`.

## Path isolation and ownership

- User A creates and removes only objects in User A's generated validation prefix.
- User B creates and removes only objects in User B's generated validation prefix.
- Cross-user and anonymous delete attempts are denial checks only; they must not remove or modify an object.
- The runner cleanup uses the owning normal-user session, never a service-role credential.

## Cleanup verification

1. Record the unique run ID and redacted generated paths before testing.
2. Record each successful create and each expected denial.
3. Remove only remaining generated validation objects using their respective owner session.
4. Verify removal by an owner-scoped read/list result or the Storage API's successful removal response, as approved for the run.
5. Record a redacted cleanup result for both users. Any failed cleanup is a `FAIL` and blocks release progression.
