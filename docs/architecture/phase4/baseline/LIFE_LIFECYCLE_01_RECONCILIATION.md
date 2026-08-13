# LIFE-LIFECYCLE-01 — Auth session lifecycle reconciliation

## Provenance and candidate

| Item | Value |
| --- | --- |
| Authoritative starting commit | `fc557c16597c353e0da5ed772acbf59ed8039010` |
| Protected source | `lib/state/providers/auth_session_lifecycle_provider.dart` |
| Protected SHA-256 | `4597114c3ba01a4bde4b60bef37f0d1e7a232f85ee2a91e54cad14e408806976` |
| Phase 2 snapshot SHA-256 | `4597114c3ba01a4bde4b60bef37f0d1e7a232f85ee2a91e54cad14e408806976` |
| Snapshot identical | yes |
| Protected line count | 1,461 |

The protected source was materialized only in a disposable candidate worktree.
The protected main-worktree source was not edited.

## Reconciliation

The candidate imports the committed single boundary authority:
`auth_session_boundary_provider.dart` (introduced by `c34a85622a9413923e2d259a110698ec01c06740`).
It removes the local duplicate `AuthSessionBoundary`,
`authSessionBoundaryProvider`, and `AuthSessionBoundaryNotifier` definitions.

No lifecycle sequencing, drain set, ownership assessment, migration, cleanup,
invalidation, identity synchronization, bootstrap, or resume policy changes are
included. The candidate has no remaining API-resolution mismatch against the
current authoritative HEAD.

## Required ordering preserved

The coordinator retains this order:

`suspend writes → drain → invalidate → cleanup/ownership → migration/claim →
identity synchronization/hydration → bootstrap → complete → conditional resume`.

The resume call remains conditional on a non-null, successfully transitioned
user. Failure paths block the boundary and do not resume writes.

## Validation plan and result

Focused coverage combines the committed runtime boundary test, Root-05 runtime
drain/isolation tests, and the lifecycle coordinator contract test. The latter
is intentionally source-contract coverage: the coordinator's private concrete
storage/cleanup providers are not injectable without a production seam, which
this source-presence reconciliation does not authorize.

The contract checks the committed boundary import/single authority, serialized
transition tail, suspend/drain/invalidate/identity/complete/resume order,
complete Root-05 drain list, derived Insights/monetization invalidation,
migration-before-identity, and failure-without-resume behavior.

Targeted analysis and exact-index focused validation are recorded after the
candidate is staged. HLM-06 remains outside this commit and must be reverified
as the protected 12-blob reconstruction after promotion.

Results: targeted analysis passed with zero diagnostics. Exact-index validation
passed with 31 focused lifecycle and Root-05 cases: the boundary test,
lifecycle contract tests, recovery-scope tests, identity/Insights isolation
tests, repository/dispatcher/extended-domain/settings/learning/reminder drain
tests. No test failed.

Authority count after reconciliation: one `AuthSessionBoundary`, one
`authSessionBoundaryProvider`, and one `AuthSessionLifecycleCoordinator`.
