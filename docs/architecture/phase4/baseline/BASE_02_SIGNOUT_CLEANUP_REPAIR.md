# BASE-02 — Sign-out cleanup preparation contract

## Scope

`LocalUserDataCleanupService.prepareForSignOut()` is the pre-remote-sign-out
boundary used by `AuthService.signOut()`. This repair restores that callable
contract only. It does not adopt the protected session-transition additions in
the working tree and does not change the untracked lifecycle provider.

## Contract

The method has the signature `Future<void> prepareForSignOut()` and runs the
same mandatory external-cleanup steps as `prepareForAccountDeletion()`:

1. clear notification routing state;
2. cancel scheduled notifications;
3. disassociate the Supabase messaging-token association; and
4. delete the Firebase messaging token.

It deliberately does not clear Hive, SharedPreferences, or secure storage.
Those stores remain available until the appropriate later ownership or account
cleanup boundary handles them.

Each step is attempted even if an earlier step fails. Failures are accumulated
and surfaced as `LocalUserDataCleanupException` after all steps finish.
`AuthService.signOut()` converts that failure to its existing
`local-cleanup-failed` error after attempting remote sign-out.

## Evidence and isolation

At BASE-02 start, the current cleanup-service file was byte-identical to the
Phase 2 protected snapshot but differed from HEAD by 174 added lines. The
protected delta includes the sign-out alias plus account-replacement and
session-transition behavior and related storage helpers. The BASE-02 candidate
is derived from HEAD and contains only the sign-out alias; none of the other
protected hunks are included.

The historical implementation provides no prior `prepareForSignOut` method.
The existing `prepareForAccountDeletion` external-cleanup boundary is the
authoritative behavioral analogue for this repaired API.

## Validation

Focused tests establish the external-only step set and the all-steps-attempted
failure behavior. The exact-index validation sandbox verifies that the
`AuthService.signOut()` call resolves against the repaired service without
using protected or untracked working-tree sources.
