# Follow-up repairs for internal candidate 3029

The 3028 stress report remains a historical record of the published and installed build. These changes address its three new findings; they do not change billing prices, entitlements, consent defaults, or production availability.

- **S9, paywall scroll:** retain the plan list position across temporary authority-loading screens using route page storage. The loading gate still prevents interaction until verification returns. A widget test scrolls the catalog, holds a refresh pending, then verifies the original offset after data returns.
- **S10, support email:** encode mail query fields using URI component escaping before launching the email app. Spaces, Unicode, newlines, ampersands and literal plus signs survive correctly. This also covers the existing account-deletion support mail path; no mail is sent by the app or tests.
- **S11, SI context disclosure:** the ready banner now describes available user-reported context, without claiming every answer cited it. Query relevance recognizes explicit minute/hour wording, so a question about five minutes does not silently exclude consented capacity. Existing consent, freshness, account and unrelated-query exclusions remain in force. The ambiguous ranking observation is retained: explicit grocery wording already selects the grocery task; no speculative ranking weight change was made.

## Candidate and publication

App source: `bc5a50c216513b8157a34330b785eb9d6187f77c`. Build tooling: `a529a415b1201aef2c0da687098d0e612200d8d9`. Signed candidate run: `34642305491`. Both authoritative version files specify `4.1.0+2026083029`.

AAB SHA-256: `c48ed72e83d9a6e6857356196ad9dd3a31193ea88c5dc787785a70b89d90fb07`. Artifact `10281470253`, archive SHA-256 `97c3e8f8b6fafb69913a533ed8c9d5abe81582b9202c78f01863266a30a5a1c7`. The downloaded archive, bundle version/package, expected upload certificate, complete nine notices, embedded mapping and nine matching native symbol pairs were independently checked. Three vendor DataStore libraries lack full symbols; this remains a diagnostics limitation. Static inspection is separate from runtime and Play acceptance.

Play Console independently read back internal release **31**, latest version **2026083029**, **Available to internal testers**, September 11 at 3:26 PM. The prior 3028 bundle is not included in the new release. Production was not published. The candidate retains the verified private billing cohort, real receipt verification, consent requirements, and disabled mock login/mode/paywall bypass. Public paid/AI activation remains contained.

## Validation

| Check | Current evidence |
| --- | --- |
| CI `34640831258` | PASS: 2,910 Flutter tests, 15 QA configuration tests, 48 Windows visual/widget checks, 17 launcher checks and 8 Linux integration groups. Zero failures/errors/skips in the counted reports. Static analysis/policy and coverage guards passed; overall coverage 74.9%. |
| Database `34640833400` | PASS: 13 SQL files / 350 cases and 142 Edge Function tests; no JUnit failure/error/skipped nodes. |
| Maestro `34640835412` | PASS: 11 journeys, zero failures/errors/skips/fatal markers. Exact-source QA APK on disposable Android API 35 emulator. Covers Planner, Creator, SI, Timeline, progression, settings, subscription containment, logout, account isolation and learned-state persistence/readback. |
| Monkey, same run | PASS: smoke 100, balanced 500, navigation 300, touch/motion 500, lifecycle 300; 1,700/1,700 events, zero fatal markers, all five cold relaunches passed. This is bounded randomized coverage on the disposable QA emulator. |
| Decision volume | PASS: 60 deterministic random scenarios with 1,000 tasks each; valid finite decisions/confidence, actionable-task exclusion, input preservation and repeat determinism. These are 60 fixture scenarios, not 60,000 independent user journeys. |
| Strict 16 KB, `34643932401` | PASS: actual page size 16,384, compatibility fallback disabled, exact-AAB-derived APK, onboarding-to-login flow passed with no fatal markers; owned guest/collectors stopped. Disposable test signer, not Play-signing or billing proof. |
| Full Windows, `34643932401` | PASS: 2,913 full-suite cases plus 15 QA configuration cases; zero failures/errors/skips. Raw reports independently counted and exact-source/candidate provenance matched. |
| Native matrix, same run | PASS: 15/15 cases across five independent hosts, 320x640 and 411x891 viewports. All raw instrumentation reports re-parsed, source-test hashes matched, no failed/errored/skipped cases or fatal markers. Fixture integration; separate from Play billing and human acceptance. |
| Installed 3029 human validation | PENDING: Moto still has Play-installed 3028. Google Play's purchase-verification preference prompt requires the owner's choice before the store update can continue. |

Focused repair regression also passed 51 cases. A redundant non-null assertion in a new test and the initially stale Android version property were corrected after the static gate rejected them. Failed/superseded CI identities remain in local evidence; no rejected source was signed. Direct dispatch of the reusable post-build workflow returned registry HTTP 404; the registered `dart.yml` post-build entry point started the same reviewed validation without code changes.

## Live billing and device boundaries

On installed 3028, the additional annual purchase used **Test card, always approves** and Google explicitly said it would not charge. Server product `chronospark_premium_annual` / plan `premium_yearly` activated. Included allowance changed from 20 to 300, purchased credits stayed 497, and total balance changed from 517 to 797. Restore kept 797 without a duplicate grant. A type-2 renewal at 20:16:29 UTC extended the test period to 20:46:18 UTC with allowance 300 and balance delta zero. Final server readback showed active annual access through 21:16:18 UTC, the same 797 balance, and lifetime spending 58. Updated-3029 restore remains pending.

The owner profile remains level 20, 36,187 XP and 1,447 completions, independently read back after cleanup. A new incomplete synthetic grocery task was saved with a five-minute duration and the existing test family-budget goal. A synthetic five-minute capacity item was explicitly consented to Home, Trajectory, Planner and SI. Home selected the grocery task and explained the five-minute limit. The item was then withdrawn and deleted; Settings returned to zero items and Home removed its context-specific explanation. No pre-existing owner record was deleted. Post-update persistence, the three repaired screens, energy/clarity/momentum and completion/idempotency remain pending. Recreate only the clearly labeled synthetic context when resuming the 3029 checks.

Final automated status: **PASS**. Installed-3029 human acceptance: **PENDING OWNER ACTION**. The Moto remains on 3028, and Google Play's purchase-verification choice is left visible. No setting was selected on the owner's behalf, no uninstall/data reset occurred, and the temporary runtime collector was stopped. Compact local evidence is in `test-results/release-3029`; the signed bundle is retained under `artifacts/releases/4.1.0-2026083029-internal-billing-verified/candidate`.

The comprehensive installed-3028 scenarios, monthly/credit lifecycle evidence and prior repairs remain in `STRESS_REPAIRS_20260911.md` and `STRESS_REPAIR_RESULTS_20260911.json`. They do not silently become installed-3029 evidence. Live grace/hold/pause/chargeback and deliberate backend-outage cases were not all freshly repeated in this pass. Destructive tests belong to disposable fixtures; owner data was not cleared and the owner was not signed out.

## Remaining release boundary

This is an internal testing release, not a production-ready declaration. The project's qualified privacy/legal and mental-health/AI-safety dispositions, reviewer-device access, and final public paid configuration/disclosure/store reconciliation remain external gates. Finite passing tests do not establish correctness for every possible input, device, network condition or future service failure. Production publication remains prohibited.
