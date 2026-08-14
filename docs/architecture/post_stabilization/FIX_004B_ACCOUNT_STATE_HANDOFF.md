# FIX-004B — Account-State Persistence Handoff

## FIX-004B1 — Profile

### Authority

Profile's authenticated runtime authority is
`profile_state_v3.<AccountStorageScope.v2Namespace>`. The namespace is the
canonical V2 base64url encoding (including any standard padding) supplied by
`AccountStorageScope`; the Profile
controller does not inspect auth state independently.

The controller reads and writes only that key while the scope is authenticated
and storage-ready. Unsafe, transitioning, blocked, and signed-out scopes do
not hydrate or persist Profile state. The authenticated backup provider uses
the same V2 key and disables its legacy Hive fallback.

### Legacy preservation

The following sources have no per-record ownership proof and are inactive:

- secure `profile_state_v2`;
- Hive `profile_box/profile_state`; and
- sanitized V1 `profile_state_v2.<legacy-user>`.

`ProfileController.migrateLegacyStorage` therefore returns
`preservedAmbiguous`: it does not copy, hydrate, delete, or mark any of these
sources as migrated. The signed-out lifecycle handoff no longer transfers the
legacy sanitized Profile record into an authenticated account.

### Auth and Settings seams

The AuthService's verified-user seed now targets the canonical Profile V2
authority. It is legitimate only because it is generated from the verified
current auth user. Settings' old Profile-sound compatibility reader has been
disabled: it returns no legacy value rather than reading a V1 sanitized Profile
record. Settings ownership migration remains FIX-004B3 work.

### Handoff and validation

Root-05 continues to drain Profile writes and invalidate `profileProvider`,
`profileValuesProvider`, and `progressionProvider` before the next storage
scope is made ready. Focused B1 coverage proves A/B isolation, restart,
signed-out-to-B isolation, ambiguous secure/V1 preservation, unsafe-scope
failure closure, and scoped read/write failure without a legacy fallback.

The exact-index candidate was validated in a detached worktree with a blank,
untracked `.env`: 44 focused Profile, lifecycle, A4 core-handoff, namespace,
Settings-compatibility, and AuthService-hydration tests passed; targeted
analysis reported zero diagnostics. The two subsequently added same-user and
transition-failure Profile proofs also passed against the clean committed tree.

Durable SI/memory and all non-Profile account-state families remain outside
this repair.
