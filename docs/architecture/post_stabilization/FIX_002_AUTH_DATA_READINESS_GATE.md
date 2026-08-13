# FIX-002 Authenticated Data-Readiness Gate

## Canonical Invariant

Authenticated domain UI is admitted only when the current authenticated user
and `AuthSessionBoundary` agree on a normalized user ID, the boundary is not
transitioning, storage is ready, and no blocking issue is present.

`authenticatedDataReadinessProvider` is the single reusable decision. It
distinguishes signed out, transitioning, storage-not-ready, blocked,
user-mismatch, and ready states from `authSessionBoundaryProvider` and the
current authenticated user.

## Router and AuthGate Ownership

The router is the primary authenticated route barrier. Protected direct and
legacy destinations redirect to the neutral bootstrap screen while the
boundary is transitioning, storage is not ready, or belongs to another user.
A boundary blocking issue routes to the distinct non-feature
`/session-blocked` screen.

`AuthGate` also consumes the same readiness decision before it returns its
authenticated child. This is a fallback admission guard, not an independent
readiness implementation.

## Safety Evidence

Focused tests cover signed out, transition, storage-not-ready, blocked,
user mismatch, ready matching user, same-user refresh, A-to-B boundary
completion, representative feature routes, and legacy aliases. Because the
router prevents those feature trees from mounting, normal UI mutations cannot
be reached before readiness.

The bootstrap route remains the neutral non-interactive transition surface;
degraded startup does not bypass the boundary because the same route guard runs
after authentication is established.

## Deliberate Non-Changes

This gate does not make storage account-scoped. Core local data, Profile,
Learning, Settings, ExtendedDomain, sign-out retention, reminder scope, and
AI/SI context invalidation remain unresolved. They are routed to FIX-003 and
later account-scope repairs.
