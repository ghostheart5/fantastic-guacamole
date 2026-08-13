# LIFE-ROOT-01A — Monetization session / refresh contract

## Result

`monetization_session_state_provider.dart` is AUTHORITATIVE current source, but LIFE-ROOT-01 requires a multi-file monetization baseline (shape C). No source-presence-only repair is safe.

## Provenance and lifecycle use

| Item | Value |
| --- | --- |
| Path | `lib/features/monetization/providers/monetization_session_state_provider.dart` |
| Status | untracked |
| Current / snapshot SHA-256 | `e8aab496fe851cd5f29b6bd43f1ab29a0e318361cf886d317c46ca00814a221d` |
| Match | yes |
| Size | 693 bytes |

It exports `invalidateMonetizationSessionState(Ref)`. The helper refreshes remote monetization providers, then invalidates paywall and credit-store controllers plus the paywall prompt. It coordinates transient account-session state; it does not create another entitlement or credit persistence authority.

The lifecycle coordinator calls `refreshMonetizationRemoteState(_ref)` only after the boundary is stable and calls `invalidateMonetizationSessionState(_ref)` during identity teardown. User A caches/controllers are discarded before user B is hydrated; refresh observes the authenticated user for the new scope.

## Diagnostic inventory

| ID | Failure | Class |
| --- | --- | --- |
| MON-DEP-01 | session-state provider URI absent | missing untracked source |
| MON-DEP-02 | `refreshMonetizationRemoteState` absent from feature provider | tracked dirty API drift |
| MON-DEP-03 | session invalidator undefined as a consequence of MON-DEP-01 | missing untracked source |
| MON-DEP-04 | shown refresh export absent | tracked dirty API drift |

## Refresh contract

Current signature is `void refreshMonetizationRemoteState(Ref ref)` in `monetization_feature_providers.dart`. It invalidates paywall, plans, subscription, entitlement, credit package/wallet/transaction, and purchase-history providers; on Android it requests pending-purchase recovery. It is a provider invalidation/remote-refresh façade with a synchronous return and unawaited platform recovery.

The feature provider is dirty and snapshot-verified (`ad4de239b76f9a0bd13a0ec37ab90975d8122a6ca19310baa18f09394e38f544`), with 19 raw hunks. Required refresh groups are `MON-FEATURE-H01` (async/foundation imports) and `MON-FEATURE-H19` (refresh and current-user helper). H02–H18 establish user-scoped provider and purchase behavior: shared baseline, not incidental source presence.

The Android branch relies on dirty snapshot-verified `purchase_repository.dart` and `recoverPendingPurchases`. Paywall and credit-store controllers are dirty consumers. The direct closure has two untracked/dirty provider sources and at least four tracked-dirty sources; no clean committed equivalent was found in history.

## Ownership and next repair

Authoritative consumers include auth lifecycle, purchase completion, paywall, credit-store, and AI-response refresh paths. Session state is a canonical session coordinator over existing provider read models and UI controllers; it should invalidate rather than recreate entitlement/credit data.

Focused eventual tests: provider resolves; A refresh/state then teardown; B refresh without A data; repeated transition; refresh failure; paywall/credit resolution; and exactly one coordinator.

**FIRST-MON-REPAIR-ID: MON-BASE-01.** First isolate the 19 feature-provider hunks and purchase-recovery API to separate refresh/session semantics from the broader user-scoped monetization rewrite. Preserve the snapshot-verified dirty files; do not commit the session provider until that boundary is proven.
