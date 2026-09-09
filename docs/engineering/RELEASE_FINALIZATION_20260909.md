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
- The dependency review found supplemental `archive` and `image` notices and
  complete notices for the shipped Inter, JetBrains Mono, Space Grotesk and
  Material Icons fonts missing from the retained QA APK. Bundle
  their complete upstream texts through Flutter's
  additional-license manifest, along with component-specific MPL source locations
  for the pinned Dart fallback certificates and Linux platform packages. Settings
  exposes the localized Flutter Licenses page. The candidate workflow verifies
  every declared notice in the actual AAB and checks the pinned Dart SDK revision
  before uploading the artifact. Native Maven/Google SDK terms remain outside the
  Dart SBOM review; this is not blanket legal approval.

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
| Eight additional notices, actual Flutter collection and localized Settings license navigation | 28 passed, zero failures/errors/skips after final typed-YAML fixes | `EF/licenses/frozen-eight-notices-manifest.json` |
| Fail-closed AAB/APK additional-license verifier | 12 passed | `scripts/test_verify_additional_licenses.py`; exact artifact entry, full-byte preservation, bounded input and SDK mismatch cases |

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

The first repaired-source CI run (`34343325387`, source `6734c1b40abdf28dfe7d3ef7692d53b30ef83403`)
completed successfully, including coverage, Windows golden comparisons and Linux
integration. Its independent database run (`34343327626`) passed 142 Edge tests
and all 349 pgTAP checks across 12 files. These precede the supplemental-notice
repair and do not replace the required final-source runs.
The CI coverage evidence reports 74.3% overall and 93.1% critical coverage;
all eight layer targets and all five critical-file targets pass without lowering
thresholds. It records 2,776 full-suite cases, 15 QA configuration cases, eight
Linux integration cases, 41 Windows golden cases and 16 launcher cases, all with
zero failures, errors or skips. These overlapping executions are not unique
end-to-end scenarios.

The old controlled Play Console tab timed out; a fresh tab in the same Edge
browser recovered access. Read-only September 9 observations show internal release
2026083021 still active and the All app bundles search for 2026083022 returning
zero results. No draft, upload or rollout was created. Other account/form evidence
must be read separately; these observations do not assert their acceptance.
The saved July 8 Data Safety declaration reports ten actioned declarations, but
Google's live URL validation rejects both its account-deletion URL and optional
data-deletion URL with HTTP 404. The exact values and UI outcome are retained in
`EF/play-console-readonly-20260909.json`. Completed-form status is not accuracy
evidence. Working public routes and truthful declaration corrections remain a
store blocker under the current publication hold; no answers were changed/saved.
The prepared version is `4.1.0+2026083022`. Actual Play delivery, public disclosure
parity, final device captures and store submission remain held. Existing level-20
screenshots show historical build 3019 and must not be labelled as this candidate.

The speech dependency forwards native events without session identifiers. The
wrapper serializes normal completion and cancellation, but cannot prove the
origin of every late native callback. Exact-device rapid restart/account-change,
background/permission denial and final-transcript tests remain required. No
100-percent correctness or all-release-requirements-passed claim is justified by
these focused receipts.
