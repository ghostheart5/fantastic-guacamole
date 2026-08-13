# MON-PURCHASE-TESTABILITY-01 — Purchase recovery test seams

## Scope

This change adds only behavior-preserving dependency seams around Android
purchase recovery. It does not change product availability, recovery policy,
journal schema, entitlement behavior, remote verification, or monetization
refresh/lifecycle wiring.

## Seams

`PurchaseRecoveryBillingGateway` owns the narrow store boundary used by
`GooglePlayPurchaseRepository`: the purchase stream, product lookup, checkout,
restore, Android pending-purchase recovery, and finalization. Its production
adapter delegates to the existing `InAppPurchase` and Android platform
addition calls.

`PurchaseVerifier` is implemented by `PurchaseVerificationService`. The
repository depends on this interface for the existing verification request;
the production implementation and its remote request contract are unchanged.

`recoveryCooldown` defaults to the existing five-second throttle. Tests may
provide `Duration.zero` to exercise retries deterministically. Production
construction retains the same throttle.

## Dynamic coverage

`test/features/monetization/unit/purchase_recovery_dynamic_test.dart` uses
memory-backed secure storage plus fake billing and verification adapters to
exercise the real repository journal state machine. It covers empty recovery,
valid and duplicate retry, wrong-user and malformed-token refusal, journal
restart, failure retry, independent multi-purchase failure, remote-grant and
lost-response crash models, finalization ordering, completed replay, and
transport recovery.

The remote duplicate model represents the existing verifier contract returning
an already-applied valid result for the same purchase token. It does not claim
to independently prove backend uniqueness; that remains owned by the remote
verification API and its server-side controls.

## Validation

Focused dynamic suite: 16 tests passed locally on 2026-08-13. Final validation
must run the staged exact-index candidate rather than rely on dirty working
tree files.
