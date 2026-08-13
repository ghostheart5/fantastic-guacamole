# BASE-03A — Lifecycle dependency closure repair DAG

## Result

The HEAD-plus-lifecycle-provider sandbox reports 29 diagnostics. They reduce to seven roots. No production source was modified or staged.

## Diagnostic inventory

Every entry is in `lib/state/providers/auth_session_lifecycle_provider.dart`.

| ID | Line | Symbol / message | Chain | Class | Root |
| --- | ---: | --- | --- | --- | --- |
| LIFE-DEP-01 | 23 | session-state provider URI absent | direct import | MISSING-UNTRACKED-SOURCE | ROOT-01 |
| LIFE-DEP-02 | 318 | `SecureStore.readAll` undefined | storage API | TRACKED-DIRTY-API-DRIFT | ROOT-02 |
| LIFE-DEP-03 | 491 | `ExtendedDomainService.migrateLegacyStorage` undefined | service API | TRACKED-DIRTY-API-DRIFT | ROOT-03 |
| LIFE-DEP-04 | 495 | `ProfileController.migrateLegacyStorage` undefined | controller API | TRACKED-DIRTY-API-DRIFT | ROOT-03 |
| LIFE-DEP-05 | 500 | `LearningController.migrateLegacyStorage` undefined | controller API | TRACKED-DIRTY-API-DRIFT | ROOT-03 |
| LIFE-DEP-06 | 783 | `ProfileController.secureStorageKeyForUser` undefined | controller API | TRACKED-DIRTY-API-DRIFT | ROOT-03 |
| LIFE-DEP-07 | 841 | `ProfileController.secureStorageKeyForUser` undefined | controller API | TRACKED-DIRTY-API-DRIFT | ROOT-03 |
| LIFE-DEP-08 | 848 | `ProfileController.secureStorageKeyForUser` undefined | controller API | TRACKED-DIRTY-API-DRIFT | ROOT-03 |
| LIFE-DEP-09 | 892 | `refreshMonetizationRemoteState` undefined | monetization feature provider | TRACKED-DIRTY-API-DRIFT | ROOT-01 |
| LIFE-DEP-10 | 1376 | `syncActionsProvider` undefined | sync provider | MISSING-PROVIDER | ROOT-04 |
| LIFE-DEP-11 | 1387 | task `cancelAndDrain` undefined | repository provider | TRACKED-DIRTY-API-DRIFT | ROOT-05 |
| LIFE-DEP-12 | 1388 | goal `cancelAndDrain` undefined | repository provider | TRACKED-DIRTY-API-DRIFT | ROOT-05 |
| LIFE-DEP-13 | 1389 | habit `cancelAndDrain` undefined | repository provider | TRACKED-DIRTY-API-DRIFT | ROOT-05 |
| LIFE-DEP-14 | 1390 | settings `cancelAndDrain` undefined | repository provider | TRACKED-DIRTY-API-DRIFT | ROOT-05 |
| LIFE-DEP-15 | 1391 | dispatcher `cancelAndDrain` undefined | repository provider | TRACKED-DIRTY-API-DRIFT | ROOT-05 |
| LIFE-DEP-16 | 1392 | recovery `cancelAndDrain` undefined | service API | TRACKED-DIRTY-API-DRIFT | ROOT-05 |
| LIFE-DEP-17 | 1393 | dynamic element not `Future<void>` | missing sync provider consequence | TYPE-MISMATCH | ROOT-04 |
| LIFE-DEP-18 | 1394 | extended-domain drain helper undefined | service API | TRACKED-DIRTY-API-DRIFT | ROOT-05 |
| LIFE-DEP-19 | 1395 | profile write drain undefined | controller API | TRACKED-DIRTY-API-DRIFT | ROOT-05 |
| LIFE-DEP-20 | 1396 | learning write drain undefined | controller API | TRACKED-DIRTY-API-DRIFT | ROOT-05 |
| LIFE-DEP-21 | 1398 | reminder `cancelAndDrain` undefined | service API | TRACKED-DIRTY-API-DRIFT | ROOT-05 |
| LIFE-DEP-22 | 1407 | identity synchronization undefined | identity provider | TRACKED-DIRTY-API-DRIFT | ROOT-06 |
| LIFE-DEP-23 | 1457 | extended-domain invalidator undefined | service API | TRACKED-DIRTY-API-DRIFT | ROOT-07 |
| LIFE-DEP-24 | 1476 | insights invalidator undefined | insights provider | TRACKED-DIRTY-API-DRIFT | ROOT-07 |
| LIFE-DEP-25 | 1491 | `syncActionsProvider` undefined | sync provider | MISSING-PROVIDER | ROOT-04 |
| LIFE-DEP-26 | 1499 | monetization session invalidator undefined | missing source | MISSING-UNTRACKED-SOURCE | ROOT-01 |
| LIFE-DEP-27 | 25 | shown monetization refresh export absent | feature provider | TRACKED-DIRTY-API-DRIFT | ROOT-01 |
| LIFE-DEP-28 | 1376 | `read` inference failure | missing sync provider consequence | TYPE-MISMATCH | ROOT-04 |
| LIFE-DEP-29 | 1393 | dynamic-call info | missing sync provider consequence | TYPE-MISMATCH | ROOT-04 |

## Root causes

| Root | Diagnostics | Priority | Files and current contract |
| --- | --- | --- | --- |
| LIFE-ROOT-01 | 01, 09, 26, 27 | P0 SOURCE PRESENCE | Untracked snapshot-verified monetization session source; dirty snapshot-verified feature provider adds refresh API. |
| LIFE-ROOT-02 | 02 | P0 API CONTRACT | Dirty snapshot-verified secure store adds `readAll`. |
| LIFE-ROOT-03 | 03–08 | P1 SHARED BASELINE | Dirty sources add legacy migration and per-user profile-key APIs. Profile controller changed since snapshot. |
| LIFE-ROOT-04 | 10, 17, 25, 28, 29 | P0 API CONTRACT | Dirty snapshot-verified sync provider adds `syncActionsProvider`. |
| LIFE-ROOT-05 | 11–16, 18–21 | P0 API CONTRACT | Dirty snapshot-verified repositories/services add identity-work drains; includes protected `SettingsRepository.cancelAndDrain`. |
| LIFE-ROOT-06 | 22 | P1 SHARED BASELINE | Dirty snapshot-verified identity provider adds authenticated-user synchronization. |
| LIFE-ROOT-07 | 23–24 | P1 SHARED BASELINE | Dirty snapshot-verified extended-domain and insights invalidators. |

No P2 incidental-import or P3 obsolete root is established by evidence.

## Monetization dependency

`lib/features/monetization/providers/monetization_session_state_provider.dart` is untracked, snapshot-verified, and has SHA-256 `e8aab496fe851cd5f29b6bd43f1ab29a0e318361cf886d317c46ca00814a221d`. It is **AUTHORITATIVE**: it refreshes remote monetization state and invalidates paywall, credit-store, and prompt controllers. It imports credit/paywall controllers plus dirty snapshot-verified `monetization_feature_providers.dart`, which supplies `refreshMonetizationRemoteState`. Its lifecycle consumer is the untracked lifecycle provider. There is no reachable-path history or committed equivalent. It cannot analyze against HEAD because the refresh export is missing.

## Startup and reverse consumer

The active startup path is dirty `app_bootstrap.dart` → lifecycle coordinator initialization → the roots above. Broad invalidation imports execute only after transition. `timeline_screen.dart` is a reverse UI consumer, not a provider prerequisite; its HEAD broken import is **UNRELATED-BROKEN-HEAD** and excluded from this DAG.

## Provenance

The 14 tracked dirty root sources are: 13 SNAPSHOT-VERIFIED, 1 CHANGED-SINCE-SNAPSHOT (`profile_controller.dart`), and 0 SNAPSHOT-UNAVAILABLE. Required untracked roots: 1, snapshot-verified.

## Minimum repair DAG

```text
LIFE-REPAIR-04 sync actions contract (5 diagnostics)
LIFE-REPAIR-01 monetization source/refresh (4)
LIFE-REPAIR-02 secure-store enumeration (1)
LIFE-REPAIR-03 legacy migration and profile-key APIs (6)
LIFE-REPAIR-05 identity-work drain APIs (11; protected settings overlap)
LIFE-REPAIR-06 identity synchronization (1)
LIFE-REPAIR-07 session invalidators (2)
                    ↓
      lifecycle provider can be revalidated for commit
```

All nodes are required. Repair 05 must isolate protected HLM-06 settings work; Repair 03 must first account for the changed-since-snapshot profile controller.

## First repair

**LIFE-REPAIR-04 — restore the `syncActionsProvider` contract.** Scope: `lib/state/providers/sync_provider.dart` only, with focused contract tests/documentation as needed. It removes five diagnostics (10, 17, 25, 28, 29), has a single snapshot-verified dirty source, is a direct lifecycle prerequisite, and has no known HLM-06 overlap. Preserve its entire dirty source, derive a HEAD candidate, and test action draining during transition.
