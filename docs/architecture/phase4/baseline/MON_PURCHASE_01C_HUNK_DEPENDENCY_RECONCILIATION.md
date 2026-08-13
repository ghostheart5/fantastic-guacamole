# MON-PURCHASE-01C — H05/H06 dependency reconciliation

## Decision

`MON-FEATURE-H06` is **MIXED REQUIRED/UNRELATED**. Do not promote its raw 17-line hunk. Promote only the one-line semantic sub-hunk **H06-REQ**: `return repository;`. Keep the listener, prompt clearing, and disposal logic as **H06-UNRELATED**.

This supersedes the prior selected map where H05 was selected while raw H06 was excluded. That map was structurally incomplete.

## H05

H05 replaces the direct `return GooglePlayPurchaseRepository(...)` expression in `purchaseRepositoryProvider` with:

```dart
final client = ref.watch(supabaseClientProvider);
final GooglePlayPurchaseRepository repository = GooglePlayPurchaseRepository(
  iap: InAppPurchase.instance,
  verificationService: ref.watch(purchaseVerificationServiceProvider),
  journalStore: ref.watch(secureStoreProvider),
  authContextLoader: () => /* current session/user context */,
);
```

It declares the concrete `repository`, supplies the new journal/auth-context constructor contract, and preserves the provider's declared return type `PurchaseRepository`. Consumers are `monetizationConnectorActionsProvider` and the Android refresh helper. H05 was selected because it covers PURCHASE-DEP-02, PURCHASE-DEP-03, and PURCHASE-DEP-05.

## H06

The raw hunk adds, in order:

1. a `verifiedPurchaseResults` listener that refreshes monetization and clears the prompt;
2. `ref.onDispose` work that disposes the repository and cancels that listener; and
3. `return repository;`.

Only item 3 is required to complete H05's provider closure. Items 1–2 are purchase-completion UI and lifecycle semantics, not needed for journal construction, Android recovery exposure, or the provider's return contract. They introduce `verifiedPurchaseResults`, `dispose`, `StreamSubscription`, prompt mutation, and an additional refresh call; including them would broaden MON-PURCHASE-01.

### Compile proof

`HEAD + H05` has a `Provider<PurchaseRepository>` closure with no return expression: the local `repository` is unused and the closure evaluates to `void`. It cannot type-check. `HEAD + H05 + H06-REQ` returns the constructed `GooglePlayPurchaseRepository` as `PurchaseRepository`; that error disappears. No H07–H18 symbol is referenced by H06-REQ.

## Revised map

| Item | Prior | Revised | Reason |
| --- | --- | --- | --- |
| Feature H01, H02, H05, H19 | selected | selected | imports, journal/auth constructor, Android exposure |
| Feature H06-REQ | absent | selected | required provider return only |
| Feature H06-UNRELATED | raw hunk excluded | excluded | purchase listener/disposal/prompt behavior |
| Feature H03, H04, H07–H18 | excluded | excluded | no transitive reference from the minimum provider-return/recovery path |
| Purchase repository H01–H42 | selected | selected | recovery/journal implementation |
| Verification H01–H03 | selected | selected | entry-bound verification and product-response validation |

Old selected count: 49. New selected count: **50** (H06-REQ is one semantic, HEAD-derived line). Old excluded count: 15. New excluded count: **15** (14 raw feature hunks plus H06-UNRELATED). Unknown selected count: **0**.

## Diagnostic and invariant coverage

| Diagnostic | Selected coverage |
| --- | --- |
| PURCHASE-DEP-01 | repository H15–H16: `recoverPendingPurchases` and Android query/reconciliation |
| PURCHASE-DEP-02 | repository H08–H09 plus feature H05/H06-REQ |
| PURCHASE-DEP-03 | repository H07 plus feature H05 |
| PURCHASE-DEP-04 | verification H01–H03 plus repository H26–H31 |
| PURCHASE-DEP-05 | feature H05/H06-REQ |
| PURCHASE-DEP-06 | feature H01/H02/H19 plus repository H15–H16 |

The selected set covers recovery, journal reads/writes, entry-bound verification, the authoritative remote `apply_verified_purchase` call, duplicate handling, consume/complete, journal removal, current-user checks, and retry. Remote idempotency remains PASS: token hash binding is unique and `apply_verified_purchase` detects an existing `(user_id, purchase_token_hash)` without granting again.

## Readiness

No further excluded feature hunk is transitively required by H06-REQ. The minimum candidate is now structurally coherent, with the same remote-idempotency condition already satisfied. The next action is **READY-FOR-MON-PURCHASE-IMPLEMENTATION**. MON-PURCHASE-01 is **SAFE WITH CONDITIONS**: exact-index validation must prove the 50-semantic-hunk reconstruction before a source commit.
