# LIFE-ROOT-02A — SecureStore `readAll` contract

## Result

LIFE-ROOT-02 is a **small shared storage API repair**, not a lifecycle or
monetization repair. `SecureStore` at `lib/data/storage/secure_store.dart` is
tracked-dirty and snapshot-identical. Its current SHA-256 is
`38bc66d4d1196aa4c17b48dccebefdd3c0c695c2099b5666eb4262ced43b9f79`, matching
the Phase 2 snapshot. HEAD blob is `620ceafad284d9a8e808d558ca3a999a3b0b010a`.

HEAD exposes individual read/write/delete and delete-all methods only. Current
snapshot source adds exactly:

```dart
Future<Map<String, String>> readAll()
```

It delegates to `FlutterSecureStorage.readAll()` for the real backend and
returns an unmodifiable snapshot of the in-memory backend. Unsupported custom
backends fail explicitly rather than silently returning incomplete data.

## Callers

| ID | Caller | Status | Purpose | Value use | Scope behavior |
| --- | --- | --- | --- | --- | --- |
| STORE-CALL-01 | `auth_session_lifecycle_provider.dart:318` | untracked authoritative lifecycle consumer | assess legacy ownership before a session transition | parses only `auth.cached_session` to identify its owner | global enumeration; no deletion; evidence is compared to expected authenticated owner |
| STORE-CALL-02 | `local_user_data_cleanup_service.dart:176` | tracked-dirty snapshot source | remove previous-session secure keys during transition | keys only | global enumeration followed by an explicit allowlist/suffix filter before deletion |

Other repository `readAll` calls belong to the independent sync-queue storage
interface and are not SecureStore callers.

## Security semantics

The contract is **global secure-store enumeration**. It is neither a current
user-scoped API nor a prefix API. That breadth is required to find legacy and
unscoped keys during ownership assessment and cleanup, but it is security
sensitive:

- callers must not expose the returned map outside trusted storage/lifecycle
  code;
- cleanup must retain the Hive cipher and Firebase messaging token and preserve
  `auth.cached_session` when an authenticated session is retained;
- cross-user deletion is limited to explicit global user keys, the previous
  normalized scope suffix, or the signed-out scope;
- lifecycle ownership assessment reads only the cached session value needed for
  owner comparison.

The current method does not decrypt or transform values itself; it returns the
secure-storage plugin's normal string map. It must not be replaced with a
broader public export API.

## Contract location and repair shape

The public façade belongs on `SecureStore`, because both lifecycle and cleanup
depend on the same canonical wrapper. The backend abstraction currently lacks
an enumeration member; the snapshot façade uses the known real/in-memory
implementations and explicitly rejects unsupported custom backends.

Recommended shape: **A — SMALL API REPAIR**: restore only the one `SecureStore`
façade hunk, preserving existing backend interface shape and read/write/delete
behavior. Do not add lifecycle code, migrations, or a second store wrapper.

## Minimum future manifest

| Path | Current status | Candidate | Role |
| --- | --- | --- | --- |
| `lib/data/storage/secure_store.dart` | tracked-dirty, snapshot-identical | MODIFY-IN-LIFE-ROOT-02 | canonical enumeration façade |
| `lib/data/services/local_user_data_cleanup_service.dart` | tracked-dirty | REQUIRED-BUT-NO-CHANGE | scoped key-filtering caller |
| `lib/state/providers/auth_session_lifecycle_provider.dart` | untracked | REQUIRED-BUT-NO-CHANGE | authoritative ownership-assessment caller |
| `lib/data/di/storage_providers.dart` | clean | REQUIRED-BUT-NO-CHANGE | canonical SecureStore construction |

Manifest count: 4. Modified-file count: 1. Required-but-no-change count: 3.
No generated code, platform migration, or additional source presence is a
prerequisite.

## History

`git log --all -S'readAll' -- lib/data/storage/secure_store.dart` found no
committed introduction. The Phase 2 snapshot is the provenance authority; the
current source is unchanged from it. The lifecycle closure records the precise
HEAD failure as `SecureStore.readAll` undefined at lifecycle line 318.

## Future test matrix

1. Empty real/in-memory enumeration returns an empty map.
2. Multiple entries and values round-trip unchanged.
3. Deleted entries are absent and enumeration is non-mutating.
4. Cleanup deletes only prior-user/global session-owned keys.
5. User A scoped keys are not selected for User B cleanup.
6. Hive cipher, Firebase token, and retained authenticated session are not
   deleted.
7. Lifecycle ownership assessment receives `auth.cached_session` and no
   unrelated caller receives an export surface.
8. Existing read/write/delete behavior remains unchanged.
