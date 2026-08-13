# FIX-003-PRE-01 Storage Namespace V2

## Versions

V1 is the historical compatibility format: trim the user ID, map an empty value
to `signed_out`, then replace every character outside `[a-zA-Z0-9._-]` with
`_`. It is preserved only for compatibility reads and assessment.

V2 is `v2.<base64url(utf8(rawUserId))>`. Authenticated IDs must be non-empty
and already trimmed; no identity is silently trimmed or case-folded. The
signed-out V2 namespace is the distinct `v2.signed_out`.

## Collision and Ownership Policy

V1 is collision-prone: `a/b` and `a?b` both map to `a_b`. V2 maps them to
different namespaces. A generated corpus of 516 supported identities produced
zero V2 collisions.

Legacy V1 data is never claimed based on its normalized key alone. Only a
separately proven owner is eligible for a future copy to V2. Ambiguous,
proven-not-owned, and signed-out legacy records are preserved without exposure,
overwrite, deletion, or automatic migration. Existing V2 always wins and is
never overwritten; a failed future migration must retain V1.

## Compatibility

The foundation reproduces the historical `baseKey.<v1-scope>` pattern used by
Profile, Learning, ExtendedDomain, and OfflineSyncQueue. SessionRecovery can
continue to capture a supplied scope string; later adoption must pass the
captured V2 value unchanged. Settings legacy profile reads remain V1-only until
their ownership decision is proven.

## Scope Limit

No active repository, controller, queue, router, lifecycle ordering, or
migration execution was rewired. FIX-003 may now introduce its boundary-derived
`AccountStorageScope` provider using this explicit V1/V2 compatibility policy.
