# FIX-003 Account Storage Scope Foundation

`AccountStorageScope` is the sole local-persistence scope model. Its provider
derives from `AuthSessionBoundary` and reads the current identity only to prove
that the boundary belongs to that identity; it has no auth listener and owns no
transition behavior.

The model has three explicit states: signed out (`v2.signed_out`), authenticated
(raw ID plus V2 Base64URL namespace), and unsafe. An authenticated transition,
storage-not-ready boundary, blocking issue, invalid ID, or boundary/user
mismatch always returns unsafe—never signed out and never a writable user scope.

V1 remains a compatibility candidate only. Its historical underscore format is
available for later Profile, Learning, ExtendedDomain, Settings, recovery, and
queue readers, but ambiguous V1 ownership remains unclaimable. No repository,
controller, queue, migration, router, or lifecycle behavior was rewired here.

The scope and namespace tests cover signed out, A/B distinction, transition and
mismatch safety, V1 compatibility, and the PRE-01 516-identity zero-collision
corpus. The next repair remains a scoped persistence implementation split; it
must select a bounded family rather than rewrite all persistence at once.
