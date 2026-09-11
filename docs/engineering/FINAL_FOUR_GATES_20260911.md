# Final four release gates - September 11, 2026

Target: public paid ChronoSpark, following the owner's revenue-launch instructions. Production publication is prohibited. This checkpoint supersedes the September 10 scope-question status, but does not approve external AI or manufacture missing review evidence.

## Native transport

The complete Android 13 USB matrix passed 15/15 in the previous checkpoint. The separate API 36 hosted matrix still failed on its larger-screen invocation. The failed job used Flutter's SDK ADB 37.0.1 against a separately pinned 36.0.2 server; matching protocol 1.0.41 was the only client compatibility check.

Tooling revision `11c040f887a0c06dbfe974146f5aefbc897313b4` replaces that protocol-only check with exact executable alignment. Only disposable GitHub-hosted integration jobs may perform it. The original SDK executable is backed up and verified, the pinned executable is copied, and its hash and version must match before any guest runs. Local and self-hosted SDK mutation is rejected. The API 36 image, emulator, Flutter SDK, application code, 15 scenarios, timeouts, zero-skip requirement and log continuity gates are unchanged.

Host validation: 54 runner and ADB-ownership tests passed, including corrupt-copy, original-preservation and host-scope rejection cases. This is not transport-fix runtime proof.

Run `34572866953` failed before emulator execution with a permissions error during executable alignment. Revision `1deac5f1` uses a byte-only copy and checks that SDK executable permissions remain unchanged; its tests also reject metadata copying. It retains the original executable backup, host restriction and hash/version verification, and adds a traceback for setup failures. All 54 host tests passed after that repair. The exact low-level source of the earlier permissions error was not captured, so this is a targeted repair rather than proven historical root cause.

Run `34574344270` completed14/15 cases: startup1, small authentication6, persistence1 and tall authentication6 passed. Planner identity failed before its test executed: VM service `streamListen` reported a disposed connection and ADB became offline. The owned server stayed alive; logs do not establish an application assertion failure, kernel panic or memory exhaustion. This confirms the executable-alignment repair alone is insufficient. The failed native artifact `10189793095` was SHA-verified and its5MB of logs/receipts retained.

Revision `d15b1bbb` isolates all five file/viewport invocations onto independent GitHub hosts. It retains the same emulator, API36 image, Flutter, test files, viewports, per-case timeout, continuous logs and canonical runner. A separate aggregation job requires five distinct host boot IDs, matching candidate/source/tooling/run/attempt identity, complete zero-skip canonical manifests,15/15 passes and successful cleanup; any failed/skipped host job fails the aggregate. There are no test retries or within-file resets. All59 host tests and actionlint passed. This addresses possible cross-invocation host-state interference; it is not proof of the low-level historical cause.

Run `34576955296` failed: startup 1, Planner 1 and tall authentication 6 passed, while small authentication and persistence failed while loading before their seven tests executed. The five distinct host boot IDs were independently read back, so cross-invocation host isolation is not a sufficient repair. The failures reported `VmServiceDisappearedException` and failure to start DDS, with ADB offline. All owned emulators and ADB servers were cleaned up. All five native artifacts and the rejecting aggregate receipt were SHA-verified; only 4.8 MB of small logs/receipts were saved, with no additional APK copy. This attempt is not a 15-test pass.

Revision `1bc25990` changes only the integration emulator pin to Google's stable 37.1.11, build 15917651, using published archive SHA-256 `95771e0ae431897b2a4bd2d97fa095f29a8b0624a7b216baf529f9306161c266`. The changed runner's 49 host tests passed. Application source, image, ADB, Flutter, test counts, isolation, timeouts and evidence gates stay unchanged. Google's release notes do not establish a fix for this exact failure; this is a controlled transport comparison, not a proven repair.

**Native gate PASS for this candidate/tooling:** https://github.com/ghostheart5/fantastic-guacamole/actions/runs/34578768789 completed successfully. Source `a8a625c55ef5f280504da5fc5a78695e45585e4c`, candidate run `34535515386`, version `2026083025`, tooling `1bc259909c69751f7d0741edeb94d698bb6bb813`. All five independent host jobs and their aggregate passed 15/15 tests, zero skipped. Five native artifacts and aggregate artifact `10191277632` were SHA-verified. Independent local readback reconciled raw JSONL terminal/test events, canonical manifests, five distinct host boot IDs, exact candidate/source/tooling identity, emulator 37.1.11 pin and complete owned-process cleanup. Receipt: `native37-independent-readback.json`. This establishes a passing maintained fixture matrix, not Play Billing, public activation or reviewer/human UAT. It does not prove the precise low-level historical cause or permanent absence of transport flakes. An unintended default canonical-CI dispatch `34572723515` was canceled, and supplies no release-pass evidence.

Strict 16KB validation passed again in run `34578768789`. Artifact `10190900373` was SHA-verified and its receipts independently inspected: actual page size 16384, compatibility fallback disabled, successful 30-second cold-launch observation, Maestro onboarding-to-login 1/1 with no skips or fatal errors, 15-second post-flow observation, and owned-process cleanup. Its AAB hash is `199e37faa0240d82acce75cfa20fbc65dce8b41ebe918d568c2b8c9a69e41f7f`. The derived APK uses a disposable test signer; this is not Play billing or authentication evidence. Only 94 KB of receipts were retained locally, avoiding another APK copy.

## Public paid functionality

Read-only live verification confirms the approved backend offers: $7.99 monthly / $69.99 annually with 300 credits per month; 100 credits for $2.99 and 300 for $7.99. Obsolete offers remain inactive. Deployed `ai-proxy` version 17 and all five bundled shared modules match local source after line-ending normalization. JWT verification is enabled.

Authenticated Play Console readback also confirms active US recurring base plans at $7.99 monthly and $69.99 annually, plus active available 100-credit/$2.99 and 300-credit/$7.99 one-time options. Both credit descriptions state no expiration, subscription or automatic refill. Each recurring plan retains one legacy price point; no existing-customer price was changed. The separate `monthly-prepaid-test` base plan remains active; local purchase selection restricts it to `requireTestPurchase`. This is catalog parity, not fresh purchase or allowance/spending evidence. No catalog setting was changed. Receipt: `play-catalog-readback.json`.

The active AI proxy still requires the private account cohort. Public Dart switches are also disabled. Merely flipping the Dart switches would not open a working public service. Public eligibility must be implemented consistently in client, backend and candidate preflight only after these existing project requirements are met:

- Anthropic account retention configuration is now verified through the existing authenticated Edge session: the recorded organization and Default workspace use30-day retention, no ZDR, feedback sharing off and global inference. The known service account remains active, Default-workspace-only, with its existing key expiring October5. The organization ID matches the prior server-held credential check. Anthropic's DPA is incorporated into accepted Commercial Terms; a separately handwritten agreement is not universally required. No negotiated exception or qualified legal opinion is inferred.
- The qualified external-AI safety review required by `EXTERNAL_GATES.md` and `externalAiSafetyReviewApproved`.
- A rebuilt signed candidate with aligned eligibility, refreshed policy/listing availability, and live consent/quote/spend/cancel/failure/refund/account-isolation verification.

The privacy-policy source and its three generated derivatives now disclose30-day provider retention, documented longer-retention exceptions, global processing, feedback off and the distinction from first-party replay retention. All21 focused legal-copy, release-contract and legal-route tests passed. These edits are local source changes, not proof of a rebuilt installed bundle or published website. The verified account settings and references are retained in `PROVIDER_RETENTION_CHECK.md`.

No provider call, credit debit, subscription grant, eligibility widening or public paid configuration change occurred in this checkpoint. No advertising is permitted in any tier.

## Reviewer access

The configured `mock@chronospark.app` account exists, is confirmed and is not anonymous. A fresh authoritative query confirms it has no active entitlement. Candidate 3025 excludes it from the compiled private cohort. The full paid-feature reviewer journey is therefore not passed.

The reviewed provision must be distinct from Google purchases: an account-bound complimentary entitlement and disclosed bounded credit allowance, with revocation, expiry, no administration privilege and no ability for another account to self-grant. The current client reads `monetization_subscription_statuses`, not the legacy `subscriptions` table; adding a legacy row would not fix access. Do not invent a Google purchase token or repurpose another customer's purchase.

Once the submitted feature configuration is established, validate the designated reviewer in an isolated profile: sign-in, onboarding, core creation/edit/completion, Planner, SI, Creator, every submitted restricted feature, cold restart, sign-out and account isolation. The owner's Moto data must remain preserved. Credentials must remain reusable, and no reviewer purchase, free trial or MFA assistance may be required.

## Production-access application

Live Console readback: Production inactive; all three eligibility checklist entries complete; `Apply for production` available. The questionnaire's narrative answers are limited to 300 characters. All three draft steps now have entered and read-back answers. Next was clicked for steps 1 and 2; final Apply remains untouched. The final readiness answer explicitly says the app is not yet ready and identifies the open gates. No application was submitted or approved.

The Testing feedback page displayed the introductory empty state, without feedback entries. A scoped search of the owner's connected Gmail recovered the July 21 Testers Community email containing a nine-page feedback report and five-page suggested application report. Both original PDFs were downloaded and fully text-extracted. The July 13-15 support thread records the initial access issue, later confirmed installations and planned daily use, and the owner's legal-document access repair. This resolves the missing historical feedback source. Automated tests and agent endurance runs remain separate evidence.

The provider's suggested application answers are not adopted wholesale: claims that phone sign-in was implemented, all features worked without discrepancies, or all later paid features were tested are not supported by the current source/evidence. The feedback report itself lists Google sign-in and email-confirmation issues despite its general no-bugs statement. Its unsigned general reference to data-protection assessment does not establish the required provider DPA or qualified AI safety review.

To make the entire draft reviewable, a provisional neutral recruitment rating was selected; it is not an owner quotation and should be confirmed before submission. Step 2 offers `I don't know` for the first-year forecast, which was selected instead of inventing an install target. The provider's Easy and 10k-100k suggestions were not adopted. Drafts and original private reports remain in ignored `test-results/final-four-gates-20260911/`, not the public repository.

Entered and read-back app-value wording (not submitted):

> ChronoSpark helps adults turn goals into manageable daily actions. It connects tasks, habits, notes and voluntary emotional check-ins with planning, reflection and visible progress. Users stay in control of suggested changes. The app never shows ads.

Entered and read-back audience wording (not submitted):

> Adults 18 and older who want one place to organize personal goals, daily responsibilities, habits and notes, then reflect on progress and adjust plans to their available time and self-reported context.

Readiness and feedback answers must be completed only from actual results and owner-provided feedback. Google approval is an external decision; an application cannot be represented as approved merely because it was submitted. Production rollout remains prohibited even after access approval.

## Evidence and remaining inputs

Current receipts: `test-results/final-four-gates-20260911/`.

Security Advisor returned informational default-deny tables and seven warnings for authenticated SECURITY DEFINER RPCs. The inspected functions have fixed empty search paths and derive account identity from `auth.uid()`. They require individual disposition, not blanket privilege revocation. In particular, device-registration token reassignment is deliberate behavior and is not equivalent to a generally account-scoped table read. This checkpoint does not claim a clean advisor report or expand its result into a full security audit.

Required external evidence remains the qualified safety-review record. The complete application draft uses a provisional neutral recruitment rating and the supported unknown-forecast answer; review the provisional rating before final submission. The initial provider sign-in blocker was resolved by the existing Edge session. A scoped Anthropic/Claude retention/DPA mail search returned no matches; the later authenticated Console readback supplies actual configuration evidence. Full reviewer provisioning and its new-candidate journey depend on the approved public feature configuration. `QUALIFIED_REVIEW_PACKET.md` prepares the concrete review material without inventing an approval.

Official requirements checked September 11:
- https://support.google.com/googleplay/android-developer/answer/14151465?hl=en
- https://support.google.com/googleplay/android-developer/answer/15748846?hl=en
- https://support.claude.com/en/articles/7996862-how-do-i-view-and-sign-your-data-processing-addendum-dpa
- https://privacy.claude.com/en/articles/7996866-how-long-do-you-store-my-organization-s-data

**Release status: not ready.**
