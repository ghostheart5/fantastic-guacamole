# LIFE-ROOT-05G6 — EXEC-6 and Root-05 exit gate

Starting authoritative commit: `ff9461e04355db1b5c75e9ae32291d5e2912c117`.

Rebuilt candidate blobs:

- R05-022 `identity_account_provider.dart`:
  `57a054478f0c02513d75c88f8e825b724663f7ff`
- R05-023 `insights_provider.dart`:
  `0dc83fa35d36b5f02085d6a4a18c5fafafcfad0d`

## Atomic implementation

EXEC-6 implements the final two Root-05 groups together:

| ID | Owner | Contract |
| --- | --- | --- |
| R05-022 | `IdentityAccountController` | `synchronizeAuthenticatedUser(User?)` retains authorized optional identity fields only for the same account, resets them for a different account, and clears memory for `null`. |
| R05-023 | Insights provider | `invalidateInsightsSessionState(Ref)` invalidates only the derived Insights bundle and the published-signature cache. |

No durable Timeline, history, domain, reminder, or account data is deleted by
R05-023. Both operations are repeat-safe.

## Validation

- Targeted EXEC-6 tests: three passing cases: same-account retention,
  cross-account/sign-out clearing, and repeat-safe derived Insights rebuild.
- Root-05 regression sources executed: `root05_exec1_repository_drain_test`,
  `root05_exec2_dispatch_recovery_test`, `root05_exec3_extended_domain_test`,
  `root05_exec4_settings_drain_test`, `learning_drain_test`,
  `reminder_orchestrator_drain_test`, and the two EXEC-6 tests. Result: 23
  executable contract cases passed (T01–T23). T24/T25 are verified by the
  lifecycle overlay resolution below.
- Additional exit-gate regressions passed: HLM-04 PlannerInput continuity and
  planner input tests (five cases), HLM-05 progression tests (six cases),
  PRE-02 recovery scope tests (two cases), and Root-03 migration tests (five
  cases). The complete exit-gate execution therefore passed 40 cases across
  13 focused files.
- Scoped analyzer for the two production owners and two EXEC-6 tests: zero
  diagnostics. The wider overlay-owner command has one unrelated existing
  advisory in `si_pipeline_provider.dart` for an unnecessary import.
- The protected lifecycle source remains unmodified and resolves all drain
  calls plus `synchronizeAuthenticatedUser(user)` and
  `invalidateInsightsSessionState(_ref)` against this baseline.

## Exact-index gate

The staged candidate contains only the two production owners, their focused
tests, and this execution record. `git diff --cached --check` is required to
pass before commit. The committed HLM-06 index entries are reconstructed and
verified separately after promotion; they are not part of EXEC-6.

Post-commit reconstruction verified all 12 HLM-06 staged entries against
their recorded blobs, including Profile
`481f1a937b4206403627c4557961f4c6cf4017d1` and SettingsRepository
`9ce97a019926bc7f33daa887416242ca5699b46b`.

## Exit status

EXEC-6 completes the 23 R05 groups. Root-05 remains safe only with the
protected lifecycle overlay and deterministic HLM-06 reconstruction preserved.
The overlay has no remaining Root-05 API-resolution diagnostics. The protected
untracked `auth_session_lifecycle_provider.dart` is ready for a separate
source-presence/reconciliation phase; it is intentionally not committed here.
