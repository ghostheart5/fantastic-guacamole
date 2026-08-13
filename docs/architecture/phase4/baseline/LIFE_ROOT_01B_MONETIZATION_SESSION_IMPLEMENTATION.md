# LIFE-ROOT-01B — Monetization session refresh baseline

## Result

The authoritative, Phase-2-snapshot-identical
`monetization_session_state_provider.dart` is committed as the sole
monetization session coordinator. It invokes the already-committed refresh
facade, then invalidates paywall, credit-store, and paywall-prompt controller
state during account teardown.

## Selected refresh semantics

`MON-FEATURE-H01`, `H05`, and `H19` are required and already present in the
committed feature-provider baseline: async dispatch, authenticated purchase
repository construction, read-model invalidation, and Android's unawaited
delegation to `GooglePlayPurchaseRepository.recoverPendingPurchases()`.

`H02` is no-longer-required for this repair because its required foundation
import is already present; its remaining auth-user import belongs to the
separate user-scoped read-model repair. `H03`, `H04`, and `H06`–`H18` remain
excluded.

## Ownership

There is one session coordinator (`invalidateMonetizationSessionState`), one
purchase and journal authority (`GooglePlayPurchaseRepository`), and the
existing entitlement, credit, and paywall provider/repository chains remain
their respective authorities. The session coordinator owns no durable
monetization state.

## User-scope behavior

At teardown the coordinator invalidates all listed monetization read models
through `refreshMonetizationRemoteState`, then clears account-owned controllers
and prompt state. Android recovery is delegated without awaiting it; the
repository's committed auth-context and journal ownership checks determine
whether recovery may proceed. This prevents session teardown from reusing the
prior prompt/controller authority, while the broader stale asynchronous
read-model guard remains intentionally out of scope for H06–H18.

## Validation

Focused tests prove prompt invalidation and repeated coordinator safety.
Targeted analysis includes the session coordinator, feature provider, its two
controller targets, and the uncommitted upstream lifecycle consumer.
