# LIFE-ROOT-03B — Legacy migration and scoped Profile-key boundary

## Diagnostic reconciliation

| Diagnostic | Required API | Current HEAD |
| --- | --- | --- |
| LIFE-DEP-03 | `ExtendedDomainService.migrateLegacyStorage({required SharedPreferences prefs, required String storageScope}) → Future<void>` | missing |
| LIFE-DEP-04 | `ProfileController.migrateLegacyStorage({required SecureStore secureStore, required HiveStore hiveStore, required String userId}) → Future<void>` | missing |
| LIFE-DEP-05 | `LearningController.migrateLegacyStorage({required SecureStore store, required String userId}) → Future<void>` | missing |
| LIFE-DEP-06 | `ProfileController.secureStorageKeyForUser(String? userId) → String` | resolved by current HEAD |
| LIFE-DEP-07 | same | resolved by current HEAD |
| LIFE-DEP-08 | same | resolved by current HEAD |

The three resolved diagnostics use the canonical static Profile helper already
committed by LIFE-REPAIR-04 and consumed by sync and lifecycle code. It returns
`profile_state_v2.<normalized-user-id>`; null/blank maps to `signed_out`, and
non `[a-zA-Z0-9._-]` characters become `_`.

## Migration helpers

| ID | Owner | Legacy source → scoped destination | Rule |
| --- | --- | --- | --- |
| LEGACY-MIG-01 | `ExtendedDomainService` | each `extended_domain.*` SharedPreferences key → `<key>.<scope>` | destination present: no-op; otherwise copy string then remove legacy key |
| LEGACY-MIG-02 | `ProfileController` | `profile_state_v2`, then legacy Hive `profile_box/profile_state` → `profile_state_v2.<scope>` | destination present: no-op; otherwise copy then remove the migrated source |
| LEGACY-MIG-03 | `LearningController` | `ai_learning` → `ai_learning.<scope>` | destination present: no-op; otherwise copy then remove legacy key |

All helpers return `Future<void>` and are called only by
`migrateTrustedLegacyUserData` during the lifecycle's trusted/signed-out
migration branch. They do not create a second runtime persistence authority.

## User-scope and ownership proof

Before migration the lifecycle reads/assesses its ownership record. A missing
or conflicting authenticated owner blocks the transition rather than guessing.
Migration runs only for a trusted legacy assessment or a signed-out owner
record. The destination scope is the new authenticated user. A successful copy
consumes the unscoped legacy source, preventing later adoption by another user;
an existing destination is never overwritten. This is deterministic across
restart. Retention when a destination already exists is intentional: the helper
does not delete data it did not migrate.

## Exact candidate boundary

| File | Selected | Excluded |
| --- | --- | --- |
| `extended_domain_service.dart` | `EXT-MIG-H02` legacy key inventory; `EXT-MIG-H06` scoped-key and static migration helper | 19 other dirty groups |
| `learning_controller.dart` | `LEARN-MIG-H02` per-user key and static migration helper | 3 other dirty groups |
| `profile_controller.dart` | `PROFILE-MIG-H01` static migration helper only | 16 other dirty groups, including HLM-05 progression, HLM-06 sound, hydration, queues, and session behavior |

Selected count: 4. Excluded count: 38. Unknown selected count: 0. Profile
construction must be `CURRENT HEAD + PROFILE-MIG-H01`; it must never copy the
protected working Profile file or change the already-committed scoped-key API.

## Manifest and readiness

| Path | Disposition |
| --- | --- |
| `extended_domain_service.dart` | MODIFY-IN-ROOT03 |
| `learning_controller.dart` | MODIFY-IN-ROOT03 |
| `profile_controller.dart` | MODIFY-IN-ROOT03, external current-HEAD candidate only |
| `auth_session_lifecycle_provider.dart` | REQUIRED-BUT-NO-CHANGE, untracked authoritative caller |

Manifest: 4 files; production modified: 3; required-but-no-change: 1.

Repair shape: **B — HYBRID LEGACY-MIGRATION REPAIR**. The exact APIs,
ownership, hunk selection, and user-scope rules are now explicit. HLM-05 and
HLM-06 remain out of the candidate; Root 05 identity draining is unrelated.

## Focused implementation tests

Test deterministic Profile key construction; A/B and signed-out keys; each
helper's empty, copy-once, existing-destination, malformed, and restart paths;
trusted-owner migration; sync/lifecycle key equality; no Profile progression
change; and HLM-06 staged-manifest preservation.
