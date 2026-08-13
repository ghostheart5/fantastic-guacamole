# MON-PURCHASE-01 — Android purchase recovery / journal boundary

## Decision

The Android recovery path is a **C — MULTI-FILE PURCHASE BASELINE**. It is snapshot-proven, has no changed-since-snapshot inputs, and can be implemented as one coherent boundary only when the feature provider compatibility hunks, purchase repository, and verification API move together. This document makes no source change.

## Entrypoint and complete path

| Item | Evidence |
| --- | --- |
| Entrypoint | `lib/features/monetization/data/repositories/purchase_repository.dart` |
| Method | `GooglePlayPurchaseRepository.recoverPendingPurchases` |
| Signature | `Future<void> recoverPendingPurchases() async` |
| Call | `unawaited(repository.recoverPendingPurchases())` from Android branch of `refreshMonetizationRemoteState(Ref)` |
| Arguments / caller | no arguments; `monetization_feature_providers.dart` H19 after it reads `purchaseRepositoryProvider` and checks the concrete type |
| Account context | current `PurchaseAuthContext` supplied by the provider from the current Supabase session; recovery proceeds only for a valid context with journal entries owned by that user |

The method awaits initialization, rejects disposed/unavailable/empty-journal state, rejects an absent or non-owning user, and throttles repeated runs for five seconds. Android uses `InAppPurchaseAndroidPlatformAddition.queryPastPurchases`; it dispatches returned purchases through `_onPurchaseUpdates` and reconciles stale entries for that user. Other platforms call `restorePurchases`. The caller intentionally does not await or receive errors; the method catches/logs platform failures.

End-to-end, discovery is Android past-purchase query -> deduplication by `_processingKey` -> `_handlePurchase` finds (or controlled-restore creates) a `_PendingPurchaseEntry` -> current-user/token checks -> `PurchaseVerificationService.verifyPurchase` with the entry's user access token -> persist `serverVerified` plus token hash -> consume (credits only) then complete the Play purchase -> remove the journal entry -> emit a verified result/complete the pending operation. Failed validation, user mismatch, missing token, store-finalization failure, or transient verification leaves the entry for later recovery; cancelled/error events remove it. Reconciliation removes only age-qualified stale entries belonging to the active user.

## Journal authority

`GooglePlayPurchaseRepository` is the **one canonical journal authority**. `_PendingPurchaseEntry` is private to it and is held in `_journal`, a map keyed by `productId`; its persisted representation is versioned JSON under secure-store key `monetization_pending_purchase_journal_v1`.

An entry has product ID, purchase type, user ID, consumable flag, creation time, `serverVerified`, optional SHA-256 purchase-token hash, and `checkoutLaunched`. The store API is `SecureStore.readString`, `writeString`, and (indirectly) no direct deletion: `_persistJournal` serializes the complete map through a serialized `_journalWriteTail`. `_removeJournalEntry` restores the in-memory entry if persistence fails. The map, processing-key set, server-verified/token-hash guard, and server-side `unique(user_id,purchase_token_hash)` evidence in the database audit provide layered duplicate protection. The client code alone does not prove durable server idempotency across a crash after finalization and before journal removal; that remains a validation condition for implementation.

## Exact API drift

| ID | File / symbol | Required current API | HEAD API | Status / authoritative side |
| --- | --- | --- | --- | --- |
| PURCHASE-DEP-01 | purchase repository / `recoverPendingPurchases` | concrete `Future<void> recoverPendingPurchases()` | absent | tracked-dirty snapshot is authoritative |
| PURCHASE-DEP-02 | purchase repository / constructor | named `iap`, `verificationService`, `journalStore`, `authContextLoader` | positional `(InAppPurchase, PurchaseVerificationService)` | tracked-dirty snapshot is authoritative |
| PURCHASE-DEP-03 | purchase repository / `PurchaseAuthContext` | user ID + access token value type | absent | tracked-dirty snapshot is authoritative |
| PURCHASE-DEP-04 | verification service / `verifyPurchase` | requires `accessToken` | HEAD obtains a global token and has no parameter | tracked-dirty snapshot is authoritative for entry-bound verification |
| PURCHASE-DEP-05 | feature provider / `purchaseRepositoryProvider` | constructs named, journal/auth-scoped repository | HEAD uses old positional constructor | tracked-dirty snapshot is authoritative compatibility caller |
| PURCHASE-DEP-06 | feature provider / refresh helper | concrete recovery call after Android type test | absent | tracked-dirty snapshot is authoritative API exposure |

`verifiedPurchaseResults` and `dispose` are real current APIs but are consumed by feature H06, which is outside this recovery baseline and remains excluded; they are not listed as required recovery compile mismatches.

## File manifest and provenance

Phase 2 root: `ChronoSparkRecovery/phase2-20260812-164222/snapshot-root/tree`.

| Path | State | HEAD blob | Current / Phase 2 SHA-256 | Match | Hunks | Disposition |
| --- | --- | --- | --- | --- | ---: | --- |
| `lib/features/monetization/data/repositories/purchase_repository.dart` | tracked-dirty | `3d2e90181a9850cf96a32ab06d6f41cc03797e1f` | `40ff61c001c875b6f0139d8f26ad63099bacc7e35d17a7c12786aebac63d7f99` | yes | 42 | MODIFY-IN-MON-PURCHASE-01 |
| `lib/features/monetization/data/services/purchase_verification_service.dart` | tracked-dirty | `13f6521cc4d01c737f5172f0db73658cb798c162` | `e73cf76352be1198ae19ad91d82aed688578a7c3ce1b461fd6ff39a0965a8b14` | yes | 3 | MODIFY-IN-MON-PURCHASE-01 |
| `lib/features/monetization/providers/monetization_feature_providers.dart` | tracked-dirty | `cab901f1a069ea03090c8385f465b5abf91ca1e7` | `ad4de239b76f9a0bd13a0ec37ab90975d8122a6ca19310baa18f09394e38f544` | yes | 19 | MODIFY-IN-MON-PURCHASE-01: H01,H02,H05,H19 only |
| `lib/data/storage/secure_store.dart` | tracked-dirty | `620ceafad284d9a8e808d558ca3a999a3b0b010a` | `38bc66d4d1196aa4c17b48dccebefdd3c0c695c2099b5666eb4262ced43b9f79` | yes | 1 | REQUIRED-BUT-NO-CHANGE; required methods are already in HEAD |
| `lib/data/di/storage_providers.dart` | tracked-clean | `dee6d2d5a9f02e38fbce7de0d2f576cb27c56521` | `fc5d047351ff78cefe63104907934a9ead299299a057d3f09209970e3b94466d` | yes | 0 | REQUIRED-BUT-NO-CHANGE |
| `lib/features/monetization/data/models/models.dart` | tracked-clean | `e95ea3f301c31a2290ae9abb9444bcdb40eb2e18` | `50a4750583081d1ebd511eadd79ce4c901c4392014e70a10bf4c506da54e9bb6` | yes | 0 | REQUIRED-BUT-NO-CHANGE |

Manifest count is 6: 3 modified and 3 required-but-no-change. Required untracked count is 0; required tracked-dirty count is 4 (the three modified files plus the secure-store dependency). No required file changed after the Phase 2 snapshot.

## Hunk map and selection

Purchase repository stable map: H01 JSON import; H02 secure-store/crypto/debug imports; H03–H05 Android constants/platform imports; H06 pending result state; H07 auth context; H08 constructor; H09 journal/runtime state; H10 verified-result stream; H11–H12 purchase entry delegates; H13–H14 guarded restore; H15–H16 recovery entry/query/reconciliation; H17 disposal; H18–H23 guarded checkout, pre-write, launch and timeout; H24–H25 stream dedupe/error; H26–H32 restored entry, status/token/verification, verified journal write and finalization; H33 consume/acknowledge; H34 user ownership helpers; H35 journal load; H36 serialized persistence; H37 rollback removal; H38 stale reconciliation; H39 operation/analytics helpers; H40–H41 product/processing helpers; H42 private journal entities and JSON parsing. H01–H05 are PURCHASE-HELPER/SHARED-BOUNDARY; H06–H14 are PURCHASE-JOURNAL/PURCHASE-USER-SCOPE; H15–H17 are PURCHASE-RECOVERY/PURCHASE-RETRY; H18–H25 are PURCHASE-JOURNAL/PURCHASE-IDEMPOTENCY; H26–H33 are PURCHASE-ENTITLEMENT/PURCHASE-ACK; H34–H38 are PURCHASE-USER-SCOPE/PURCHASE-RETRY; H39–H42 are PURCHASE-HELPER/PURCHASE-JOURNAL.

Verification stable map: H01 explicit access-token API (PURCHASE-USER-SCOPE); H02 remove global-token lookup (PURCHASE-USER-SCOPE); H03 reject mismatched verified product (PURCHASE-IDEMPOTENCY). Feature selection is H01/H02 (imports), H05 (constructor/auth context), and H19 (Android recovery exposure), all PURCHASE-RECOVERY/SHARED-BOUNDARY.

Selected exact hunks: repository H01–H42; verification H01–H03; feature H01,H02,H05,H19. Selected count: **49**. Excluded feature hunks: H03,H04,H06–H18 (15); excluded count: **15**. Unknown selected count: **0**. Secure-store's `readAll` hunk is excluded as unrelated.

## Invariants and tests

The intended code evidence covers: a journal pre-write before checkout; one map entry per product; in-process stream dedupe; active-user checks before verification and finalization; unknown product/empty token no grant; verified marker persistence before consume/complete; journal deletion only after finalization; retryable retained entries after transient failure; and scoped stale cleanup. Server-side purchase-token uniqueness is documented evidence, but must be validated at implementation time to prove crash-safe no-double-grant semantics.

Required tests: empty journal; one valid pending purchase; duplicate invocation; journal duplicate guard; wrong user; malformed/unknown product/token; consume/ack ordering; verification/finalization retry; later recovery after a failure; entitlement once; JSON round-trip; Android refresh safe unawaited invocation; and A-to-B isolation.

## History and next action

`git log --all -S` finds no committed introduction for `recoverPendingPurchases` or the journal key. `df31ea83` and `efbe8b15` are the only relevant repository-history references; Phase 2 byte identity is the authority for current recovery source. The next action is **READY-FOR-MON-PURCHASE-IMPLEMENTATION**, subject to a server idempotency test/contract check. MON-PURCHASE-01 is **SAFE WITH CONDITIONS**; no prerequisite repair is named.
