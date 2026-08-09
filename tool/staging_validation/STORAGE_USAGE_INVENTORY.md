# Storage Usage Inventory

Status: `STORAGE_VALIDATION_REQUIRED`.

This is a repository-only inventory. No bucket was listed or modified, no object was uploaded/downloaded/deleted, and no policy query was executed.

## Confirmed Supabase Storage usage

ChronoSpark has an active cloud-backup gateway, `SupabaseStorageCloudBackupGateway`, in [lib/data/services/sync_service.dart](../../lib/data/services/sync_service.dart). It is selected by the sync provider when the Supabase backend is enabled. Storage is therefore in the application release path.

## Bucket and policy intent

| Item | Repository evidence |
| --- | --- |
| Bucket | `chronospark-sync` |
| Public access | Intended private (`public = false`) |
| Object ownership boundary | First path component must equal `auth.uid()` |
| Authenticated operations intended | Select, insert, update, delete on an owned path |
| Anonymous operations intended | No policy or grant is defined; expected denial |

The intended bucket and policies are declared in [supabase/migrations/202607110002_data_policies.sql](../../supabase/migrations/202607110002_data_policies.sql). A prior read-only staging inventory recorded zero buckets and objects before migration application. That historical snapshot does not establish the current effective staging Storage state.

## Path patterns and file content

| Flow | Bucket | Path pattern | Object content |
| --- | --- | --- | --- |
| Full backup upload/download | `chronospark-sync` | `{authenticated-user-id}/backup/full_backup.json` | JSON full backup snapshot |
| Tasks backup upload/download | `chronospark-sync` | `{authenticated-user-id}/backup/tasks_backup.json` | JSON task backup snapshot |
| Devtools round-trip probe | `chronospark-sync` | `{authenticated-user-id}/validation/roundtrip-{UTC timestamp}.json` | JSON validation payload; execution is not authorized by this inventory |
| Backend health check | `chronospark-sync` | `{authenticated-user-id}/backup` | List-only health/access probe |

## Upload flows

- `syncToCloud()` serializes a full backup to JSON and uses `uploadBinary` with `application/json`, `cacheControl: 0`, and `upsert: true`.
- The task-specific upload flow uses the same implementation with `tasks_backup.json`.
- No runtime Supabase Storage upload for profile avatars, creator media, audio, video, or attachments was found. The similarly named domain use-case files are empty class declarations and do not call Storage.

## Download flows

- Full and task backups use `storage.from('chronospark-sync').download(...)` and decode JSON.
- A `404` is treated as an empty cloud backup by the application.
- No signed URL or public URL download flow was found.

## Delete flows

- Production application backup code contains no Storage delete call.
- The developer-only round-trip validator contains `remove([path])` for its generated validation object when explicitly enabled.
- Deletion validation remains blocked until the bucket, policy, test path, and cleanup contract are approved.

## Signed and public URL usage

- `createSignedUrl(...)`: no repository usage found.
- `getPublicUrl(...)`: no repository usage found.
- No other Supabase bucket names were found in active runtime Storage API calls.
