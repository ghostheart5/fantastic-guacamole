# MON-BASE-01 — Monetization refresh / purchase-recovery boundary

## Decision

**Do not implement MON-BASE-01 yet.** The smallest complete refresh path is blocked by the uncommitted, snapshot-verified purchase-journal/recovery subsystem. The correct repair mode is **D — PRE-REPAIR REQUIRED**. The one next repair is **MON-PURCHASE-01**: isolate the purchase repository's journal-backed, auth-scoped `recoverPendingPurchases` API before any feature-provider or session source is committed.

This is a read/provenance record only. It authorizes no monetization source, lifecycle source, or HLM-06 change.

## Provenance

Phase 2 snapshot root: `ChronoSparkRecovery/phase2-20260812-164222/snapshot-root/tree`.

| Path | Status | HEAD blob | Current SHA-256 | Phase 2 SHA-256 | Current = snapshot | Hunks | Role |
| --- | --- | --- | --- | --- | --- | ---: | --- |
| `lib/features/monetization/providers/monetization_session_state_provider.dart` | untracked | absent | `e8aab496fe851cd5f29b6bd43f1ab29a0e318361cf886d317c46ca00814a221d` | same | yes | n/a | session coordinator/source presence |
| `lib/features/monetization/providers/monetization_feature_providers.dart` | modified | `cab901f1a069ea03090c8385f465b5abf91ca1e7` | `ad4de239b76f9a0bd13a0ec37ab90975d8122a6ca19310baa18f09394e38f544` | same | yes | 19 | provider API and read-model refresh |
| `lib/features/monetization/data/repositories/purchase_repository.dart` | modified | `3d2e90181a9850cf96a32ab06d6f41cc03797e1f` | `40ff61c001c875b6f0139d8f26ad63099bacc7e35d17a7c12786aebac63d7f99` | same | yes | 42 | Google Play recovery/journal authority |
| `lib/features/monetization/presentation/controllers/paywall_controller.dart` | modified | `77eb1b703e043df1afe68246fa99ea493e5f78e0` | `36abab71a3887a030df18d835e7f272d4e024882fba54866c230f6dab9f30102` | same | yes | 7 | existing paywall consumer |
| `lib/features/monetization/presentation/controllers/credit_store_controller.dart` | modified | `c9ff0b2e1863e0034fae0fb4173f5adc32ba079b` | `27961e312bffcb70aa300dc3db2f4a015a7176ba23e3e37bc08a0e9a8210e45d` | same | yes | 6 | existing credit consumer |

No required file differs from its Phase 2 snapshot; changed-since-snapshot count is zero. `auth_session_lifecycle_provider.dart` is the upstream untracked caller, not a MON-BASE-01 source candidate, and remains explicitly excluded.

## Feature-provider hunk map

| ID | Current line region | Symbols/change | Classification | Dependency/consumer | Refresh disposition |
| --- | ---: | --- | --- | --- | --- |
| H01 | 1–2 | `dart:async` | MON-REFRESH / MON-HELPER | `unawaited` in H19 | conditional selected |
| H02 | 14–16 | `authUserProvider`, `foundation` imports | SHARED-BOUNDARY | foundation is needed by H19; auth import supports H03/H05–H18 | conditional selected; mixed import hunk |
| H03 | 22–30 | owned HTTP disposal | MON-DI | HTTP client | excluded |
| H04 | 31–37 | `monetizationAuthUserIdProvider` | MON-SESSION | H07/H10/H12/H14/H16/H18 | excluded |
| H05 | 63–79 | journal/auth-context purchase repository constructor | MON-PURCHASE-RECOVERY / MON-DI | H19 concrete Google Play recovery | conditional selected, blocked on MON-PURCHASE-01 |
| H06 | 80–96 | verified-result listener and repository disposal | MON-PROMPTS / MON-PURCHASE-RECOVERY | purchase completion UI | excluded: not required by auth refresh |
| H07 | 125–154 | user-scoped paywall helper | MON-PAYWALL / MON-SESSION | paywall read model | excluded |
| H08 | 155–172 | public paywall wrapper | MON-PAYWALL / MON-SESSION | paywall read model | excluded |
| H09 | 173–179 | user-scoped subscription helper | MON-ENTITLEMENT / MON-SESSION | subscription read model | excluded |
| H10 | 180–194 | public subscription wrapper | MON-ENTITLEMENT / MON-SESSION | subscription read model | excluded |
| H11 | 195–215 | user-scoped entitlement helper | MON-ENTITLEMENT / MON-SESSION | entitlement read model | excluded |
| H12 | 216–239 | public entitlement wrapper/expiry timer | MON-ENTITLEMENT / MON-SESSION | entitlement state | excluded |
| H13 | 240–254 | entitlement tier async-state handling | MON-ENTITLEMENT | entitlement UI | excluded |
| H14 | 255–261 | user-scoped wallet helper | MON-CREDITS / MON-SESSION | wallet read model | excluded |
| H15 | 262–280 | public wallet wrapper | MON-CREDITS / MON-SESSION | wallet read model | excluded |
| H16 | 281–289 | user-scoped transactions helper | MON-CREDITS / MON-SESSION | transaction read model | excluded |
| H17 | 290–308 | public transactions wrapper | MON-CREDITS / MON-SESSION | transaction read model | excluded |
| H18 | 309–315 | user-scoped purchase-history helper | MON-CREDITS / MON-SESSION | purchase-history read model | excluded |
| H19 | 316–337 | public purchase-history wrapper, `refreshMonetizationRemoteState`, `_isCurrentSupabaseUser` | MON-REFRESH / MON-HELPER | lifecycle/session/purchase/paywall/credit consumers | conditional selected |

The raw Git diff has exactly these 19 headers. No unknown hunk is selected.

## Exact refresh behavior

`void refreshMonetizationRemoteState(Ref ref)` synchronously invalidates: `paywallProvider`, `subscriptionPlansProvider`, `currentSubscriptionProvider`, `premiumEntitlementProvider`, `aiCreditPackagesProvider`, `aiCreditWalletProvider`, `aiCreditTransactionsProvider`, and `purchaseHistoryProvider`.

On non-web Android only, it reads `purchaseRepositoryProvider`; if the value is `GooglePlayPurchaseRepository`, it starts `unawaited(repository.recoverPendingPurchases())`. It does not await, return errors, retry, set prompt state, or directly reload a provider. Provider recomputation occurs only when watched/read later. `recoverPendingPurchases` catches its own platform errors and logs a warning, so the facade has no error channel.

The session invalidator then calls this facade and invalidates `paywallControllerProvider`, `creditStoreControllerProvider`, and `paywallPromptProvider`. The stable-transition lifecycle caller invokes the facade only after its session boundary is stable.

### Minimum lifecycle contract

| Effect | Classification | Why |
| --- | --- | --- |
| Invalidate subscription, entitlement, wallet, transactions, history and paywall read models | REQUIRED-FOR-AUTH-LIFECYCLE | prevents prior account remote results from being reused after a transition |
| Invalidate plans and credit packages | REQUIRED-FOR-CONSISTENCY | they share the refresh facade; no user data is written |
| Android pending-purchase recovery in active authenticated scope | REQUIRED-FOR-CONSISTENCY | reconciles durable pending entries for the active user; it is not a prerequisite before invalidation |
| Invalidate paywall/credit controllers and prompt during teardown | REQUIRED-FOR-AUTH-LIFECYCLE | clears transient account-owned UI state |
| Purchase-completion listener and prompt clearing | OPTIONAL-UI-REFRESH | purchase-flow behavior, not required for an auth transition |
| H05–H18 user-scoped read-model rewrite | REQUIRED-FOR-CONSISTENCY in its own repair, but not required for H19 compilation | must be isolated independently |

## Purchase-recovery dependency

The concrete authority is `GooglePlayPurchaseRepository.recoverPendingPurchases(): Future<void>` in `purchase_repository.dart`. It awaits repository initialization; exits if disposed, journal unavailable/empty, or no valid current auth context with a matching pending entry; throttles recovery; on Android calls `queryPastPurchases`, forwards results to purchase handling, and reconciles journal entries absent from the store. Elsewhere it calls platform restore. It catches and logs errors.

It depends on a secure-store journal, `PurchaseAuthContext` loader, initialized stream subscription, pending-operation/journal state, and repository disposal. HEAD instead has the positional two-argument constructor and no recovery method. Therefore the classification is **A — required for the current Android recovery branch, but not required before provider invalidation itself**. Its correct authority remains the purchase repository, not the session coordinator.

## Ownership and scope invariants

| Concern | Canonical authority |
| --- | --- |
| Session coordination | `invalidateMonetizationSessionState(Ref)` |
| Purchase recovery | `GooglePlayPurchaseRepository` journal/recovery API |
| Entitlement state | entitlement repository/provider chain |
| Credit state | AI credit repository/provider chain |
| Paywall state | paywall service/provider chain |
| Prompt state | `PaywallPromptNotifier` |

Evidence supports these invariants: teardown invalidates A's read models/controllers before B hydration; refresh reads the currently exposed provider/repository; recovery requires a valid current auth context and pending entries for that user; repeated recovery is throttled; and recovery failures do not repopulate a provider directly. The present H19 facade alone does **not** prove stale asynchronous A responses cannot complete into B's unscoped HEAD providers. That guarantee is the purpose of H05–H18 and remains outside this repair. Thus invariants 1, 3, 4, 6, and 7 are directly covered; 2, 5, and 8 require the separate user-scoped read-model boundary.

## Dependency manifest and selection

| File | Classification | Repair class | MON-BASE-01 disposition |
| --- | --- | --- | --- |
| session-state provider | MODIFY-IN-MONBASE01 | SOURCE-PRESENCE / SNAPSHOT-SEMANTIC-RESTORE | conditional, after prerequisite |
| feature providers | MODIFY-IN-MONBASE01 | HEAD-STALE-API / PROVIDER-EXPOSURE | conditional candidates H01, H02, H04, H19 |
| purchase repository | MODIFY-IN-MONBASE01 | HEAD-STALE-API / SNAPSHOT-SEMANTIC-RESTORE | cannot select until MON-PURCHASE-01 proves the minimal atomic hunk set |
| paywall controller | REQUIRED-BUT-NO-CHANGE | NO-CHANGE | imported/invalidate target only |
| credit-store controller | REQUIRED-BUT-NO-CHANGE | NO-CHANGE | imported/invalidate target only |
| auth lifecycle provider | REQUIRED-BUT-NO-CHANGE upstream consumer | NO-CHANGE | explicitly excluded from commit |

Dependency-manifest count: **6**. Modified-file count: **3**. Required-but-no-change count: **3**. Required untracked source count: **1** (the session-state provider). Required tracked-dirty count: **4** (feature provider, purchase repository, paywall controller, credit-store controller).

Planned feature selection, contingent on MON-PURCHASE-01: **H01, H02, H05, H19**. Excluded feature hunks: **H03, H04, H06–H18**. The selected count is 4, excluded count is 15, and unknown selected count is 0. Purchase repository hunks are intentionally **not selected** in this phase; its 42 raw hunks require a separate exact-hunk map.

## Method / hunk matrix

| Effect | Required candidate |
| --- | --- |
| refresh facade/invalidation | feature H01, H02, H19 |
| Android purchase recovery dispatch | feature H01, H02, H05, H19 + MON-PURCHASE-01 atomic repository set |
| entitlement, credit, paywall invalidation | feature H19 (providers already exist in HEAD) |
| prompt invalidation | existing session provider + existing prompt provider; no feature hunk |

## History and test plan

`git log --all -S` found no committed introduction of either `refreshMonetizationRemoteState` or `recoverPendingPurchases`; HEAD history shows the feature-provider stack introduced by `ed67ef3` and later checkpoint/QA commits, but no committed lifecycle equivalent. The Phase 2 snapshot is therefore the provenance evidence; it is not authority to commit all adjacent dirty work.

Eventual tests: session provider resolves; stable lifecycle refresh; teardown clears A; B cannot receive A state; recovery requires correct user scope; repeated recovery is safe; failed recovery leaves no stale authority; entitlement/credit/paywall/prompt states resolve and invalidate; no duplicate coordinator; and existing purchase/paywall/credit consumers resolve.

## Next action

**NEEDS-PURCHASE-RECOVERY-PRE-REPAIR — MON-PURCHASE-01.** LIFE-ROOT-01 remains **BLOCKED** until that exact repository boundary is isolated and validated, after which the conditional feature/session candidates can be re-evaluated without importing H03/H05–H18.
