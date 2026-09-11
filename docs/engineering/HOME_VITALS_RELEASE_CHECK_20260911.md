# Home vitals audit and release checkpoint — September 11, 2026

## Scope and identity

Canonical app checkout: `ChronoSpark-app-only-priority2`, branch
`fix/aab-prebuild-cleanup-20260905`, base commit
`0f4697616324b8ab3977cc4a6a9476ebebc82bb1`. This checkpoint describes the
working-tree repairs, not a newly built or installed AAB. Unrelated existing
changes, release artifacts, screenshots, device profiles and shared Git storage
were preserved. No production publication is authorized or performed.

## Findings and repairs

| Finding | Repair and resulting behavior | Evidence |
|---|---|---|
| Home had no usable Energy/fatigue input path | Tapping Energy or Clarity opens an optional check-in. Saving reports a value explicitly; untouched defaults cannot be saved. Cancel changes nothing; Clear removes the observation. | Dialog widget tests and actual Home widget interaction |
| Clarity looked like a measured personal attribute | Clarity remains an estimate of `100 - reported fatigue percent`. The check-in explains that this is not a cognitive assessment; tooltips and semantics describe its basis. Unreported fatigue remains Not checked. | Widget assertions; source and accessibility semantics inspection |
| New reports needed a freshness limit | Energy and fatigue expire independently after two hours, or at session end. Updating one report does not renew the other. Reports remain in session state, not durable identity. Account-generation checks reject stale dialog saves. | Independent-expiry and stale-save regression tests |
| Home's Momentum evidence differed from Trajectory | Home now consumes the same Trajectory model, baseline and recent-evidence gate. Lifetime completions and the separate composite Momentum Engine score cannot bypass that gate. | Real provider graph test: recent evidence, thresholds, loading with previous data, error and recovery |
| The second Home Momentum/Pressure report bypassed that gate | Both Home displays use one derived baseline view. Loading, error, empty and learning states withhold numerical Momentum/Pressure conclusions. Scenario projections do not replace baseline values. The top Momentum card opens Trajectory. | Shared-provider assertions, navigation test and unchanged golden snapshots |
| Execution counts could remain stale without new logs; UTC logs used raw calendar dates | One canceled-on-dispose timer refreshes at the next local midnight or relevant 7-/14-day evidence boundary. Today uses local dates. Explicit Trajectory refresh also invalidates execution counts. | Clock-driven expiry and UTC-to-local midnight tests |
| Invalid numeric values could be tagged as observations | Non-finite controller inputs are rejected. SI observation getters require finite values within 0–1. | NaN/infinity and existing SI state tests |
| Provider-retention configuration flag lagged completed evidence | `externalAiProviderRetentionVerified` is now true with the dated evidence reference. Public subscriptions, AI, credit spending and the separate safety-review flag remain false. | Launch-containment and paid-offer release contracts |

Energy/fatigue flow through `siStateProvider` and the existing
`consentedHumanContextProvider` into Home and shared planning/Trajectory
aggregation. They are not inferred from task completions, XP or level. The
optional check-in explains its planning purpose and lifetime. External requests
retain their separate eligibility, disclosure and consent gates.

## Validation

- Final combined gate: **227 passed**, zero failures, errors or skips. This
  includes the 73 app/provider/widget checks and 154 release/configuration checks
  rerun together against the final source patch.
- Full `lib` analysis plus changed tests: **PASS, no issues found**.
- `git diff --check`: **PASS**. Git emitted only its existing line-ending
  normalization notice for the edited Home golden-test source file.
- Existing Home golden images matched at 320, 375 and 500 widths; no baselines
  were regenerated to accept these repairs.
- Evidence directory: `test-results/vitals-audit-20260911/`.
  `accepted-vitals-manifest.json`, `all-release-contracts-manifest.json`, and
  `final-gate-manifest.json` are the canonical test-runner receipts.
  `source-receipt.json` records SHA-256 hashes of the 17 changed code/test files.
- Intermediate failed runs are retained: a misplaced import, ambiguous test
  locator and externally owned widget-test container cleanup were corrected.
  They are not represented as passing evidence.
- Release runner fixture tests exercise host-side orchestration contracts.
  No Android monkey stress run or level-20 endurance test was performed.

These are source/host tests. No new signed artifact, Play billing lifecycle,
physical-device interaction or Google review is implied.

## Remaining release gates

1. **Qualified privacy and AI-safety review remains external.**
   `EXTERNAL_GATES.md` requires a qualified reviewer and a "Signed dated review"
   for privacy/legal and mental-health safety. No such completed record was
   supplied. The prepared review packet remains in
   `test-results/final-four-gates-20260911/QUALIFIED_REVIEW_PACKET.md`.
   This is a project requirement, not a claim that Google universally requires
   a named professional certificate for every productivity app.
2. **Public paid configuration and exact-candidate purchase/credit validation
   remain open.** Recording the verified provider settings does not turn on
   public paid features. Client, backend eligibility, build preflight and final
   disclosures must agree before a production candidate is validated.
3. **Full reviewer access remains open.** A fresh read-only production query
   confirmed the designated account is confirmed/nonanonymous, with no current
   entitlement or wallet. No purchase ownership, privilege or balance was
   changed. The provision still needs an explicit bounded complimentary grant,
   final-candidate eligibility and an isolated end-to-end reviewer journey.
   A fake Google purchase or local paywall bypass would not satisfy this gate.
4. **The final signed candidate needs its own native validation.** The prior
   native 15/15 and strict 16 KB pass belongs to candidate 3025, source
   `a8a625c55ef5f280504da5fc5a78695e45585e4c`, run `34578768789`.
   Those receipts are preserved and do not validate this newer working tree.

Google's current reviewer-access guidance was rechecked during this audit:
[Requirements for providing sign-in details for review](https://support.google.com/googleplay/android-developer/answer/15748846?hl=en).
Reviewers must be able to access submitted restricted functionality without a
purchase. The production-access questionnaire remains an unsubmitted draft;
production rollout remains prohibited.

**Release status: not ready.**
