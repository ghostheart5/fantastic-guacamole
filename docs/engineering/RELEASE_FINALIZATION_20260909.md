# Release finalization - September 9, 2026

## Scope and authority

The user approved the reviewed repairs, commit/push, backend completion, signed
internal-testing AAB preparation, and a fresh complete applicable test rerun and
audit. Public legal-page publication and Google Play upload/rollout remain held.
Monkey testing, level-20 endurance and alteration of the real Moto installation
remain excluded. Existing dirty level-20/graphics documents and artifacts are
preserved. Source base: `c2d83bc0dd0c7b512e2d2b152a7ca2a230c73b30` in
`ChronoSpark-app-only-priority2`, branch `fix/aab-prebuild-cleanup-20260905`.

This record supplements `RELEASE_AUDIT_REPAIRS_20260909.md`. That report's earlier
2,687-test, Edge and Android results are historical and do not attest the later
voice changes below. Final immutable source/build/run identities must be recorded
in the completion evidence before accepting the candidate.

## Additional repairs from the second review

- Both actual microphone controls now show English/Spanish device speech-provider
  processing disclosure before each dictation, including when Android permission
  was granted previously. Decline, backgrounding and an account/provider lifetime
  change prevent capture. Recognized text still requires explicit review/send.
- Voice startup checks cancellation after TTS, permission and initialization;
  concurrent startup, disposal and delayed native startup are fenced. Provider
  invalidation can safely reuse the notifier. Native shutdown barriers prevent a
  new controller session while cleanup remains pending.
- The speech adapter reports sanitized native startup/stop/cancel failures,
  retains the final correction after `notListening`, completes once at the
  terminal callback, and bounds the wait for terminal completion during stop.
  The production adapter shares the dependency's singleton speech engine.
  A bounded native-start acknowledgement also rejects silent startup refusal.
- Background handling begins the microphone stop synchronously before waiting
  for TTS shutdown. Planner and SI display localized safe voice-failure feedback.
- Android's speech-recognition service query is declared. Canonical privacy,
  generated copies, Settings rationale and the Data Safety draft describe the
  device provider's possible remote audio processing. These copies are prepared
  locally; public parity remains held.
- The public-route build verifier now checks the current contained/private
  billing wording without changing its publication guard.
- Backend repair dispatch uses the existing allowed tooling branch and separate
  immutable app checkout, with successful exact-source CI checked first. It
  preserves production branch restrictions, private secret handling, fixed
  project/migration/grant guards and the explicit three-function deployment scope.
- Regression coverage adds interrupted deletion/backup recovery, subscription
  account changes during verification/acknowledgement/persistence, overlapping
  planning proposals and progression restore failure/validation cases. Coverage
  targets were not lowered; only a fresh complete LCOV run can close them.
- Internal billing instructions identify the current approved catalog and
  monthly allowance/top-up policy while preserving the original setup as history.

## Executed focused evidence

Evidence root `EF = test-results/release-finalization-20260909/`; `E =
test-results/release-repairs-20260909/`. Counts below overlap the later full suite
and must not be added as distinct end-to-end coverage.

| Check | Terminal result | Evidence |
| --- | --- | --- |
| Actual Planner/SI controls, localized error feedback and consent | 57 passed, zero failures/errors/skips | `EF/voice/screens-complete-manifest.json` |
| Adapter and controller lifecycle contracts | 53 passed, zero failures/errors/skips | `E/finalization/voice-adapter/startup-ack-manifest.json` |
| Shell background lifecycle | 12 passed | `E/voice/lifecycle-ordering-final-manifest.json` |
| Domain proposal/restore regressions | 19 passed | `EF/domain/manifest.json` |
| Critical authentication/backup/paywall regression files | 165 passed | `E/finalization/critical-coverage/final-summary.json` |
| Candidate controls | 21 passed | `EF/precommit-candidate-tests.txt` |
| Tooling-compatible backend rollout contracts | 10 passed | `E/backend/rollout-tooling-validation.json` |

Intermediate test failures remain retained. A temporary test-edit encoding issue
and offscreen/continuous-animation harness assumptions were corrected; final
screen tests preserve every existing assertion and compare the original text.
The native adapter tests use mocked platform channels and record no microphone
audio. Host tests do not establish native shutdown or native event origin.

## Backend preservation and remaining execution

The private prior function bodies and version/configuration metadata are retained
outside checkout/artifacts with ACL access limited to the current user and SYSTEM.
`E/backend/ROLLOUT_FINALIZATION.md` records hashes and a concrete partial-success
recovery procedure. After the one migration commits, recovery must roll forward
only remaining reviewed functions; never regrant the obsolete wallet RPC or
restore ungated AI. The latest Google Play RTDN test was independently read as
processed on September 8 at 21:06:54 UTC; preflight must check freshness again.

Complete two independent successful `ci.yml` and `supabase-database.yml` runs on
the same final app SHA, fresh coverage target audit, current-source Android
integration and eleven-flow Maestro replay, signed-AAB inspection, deployed
backend readback, and applicable safe runtime verification. Record failures and
unexecuted requirements directly; a passing mocked or QA check cannot stand in
for a real purchase, deletion, credit/provider operation or Play-signed upgrade.

The controlled Play Console tab still times out. Current unused version maximum,
forms and account configuration are not freshly verified by that UI observation.
The prepared version is `4.1.0+2026083022`. Actual Play delivery, public disclosure
parity, final device captures and store submission remain held. Existing level-20
screenshots show historical build 3019 and must not be labelled as this candidate.

The speech dependency forwards native events without session identifiers. The
wrapper serializes normal completion and cancellation, but cannot prove the
origin of every late native callback. Exact-device rapid restart/account-change,
background/permission denial and final-transcript tests remain required. No
100-percent correctness or all-release-requirements-passed claim is justified by
these focused receipts.
