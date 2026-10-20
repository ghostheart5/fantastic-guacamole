# Axiomara Google Play release preparation

October 2, 2026. Prepared for the owner from the local checkout and current GitHub evidence. Production release status: **not ready**. The local 3102 repairs are prepared for source review and hosted validation; a signed, accepted public 3102 artifact and its production evidence are still missing.

## Project locations

| Material | Location |
| --- | --- |
| Active source and this preparation | `C:\jtmp\axiomara-public-release-pipeline-20260926` |
| GitHub repository | [ghostheart5/fantastic-guacamole](https://github.com/ghostheart5/fantastic-guacamole) |
| Local release preparation and historical artifacts | `%USERPROFILE%\Documents\ChatGPT\axiomora\release-preparation` |
| Historical 3100 source | `%USERPROFILE%\Documents\ChatGPT\axiomora\tutorial-route-repair-3100` |
| Historical 3099 source | `%USERPROFILE%\Documents\ChatGPT\axiomora\repair-20260930` |

The support folder is spelled `axiomora`. These locations are not interchangeable release candidates. The Android package remains `com.ghostheart5.chronospark`; the intended next candidate is `4.2.3+2026083102`.

## Source and GitHub evidence

- Original clean local branch `claude/first-run-guide-repairs` was at `2d00d85a2f76c6814adf2fd2a209b8476283a1b4`, containing 3102. That commit was absent from GitHub and had no hosted Actions runs when queried.
- GitHub `main` was `ff1a668cd7e310ea327b9510f42c568afca6550e`, still version 3100, with the candidate source-guard repair from PR 161.
- GitHub's repair branch was `3754d61d6421961dfdffb575c794aeb63b253b42`, version 3101. [PR 160](https://github.com/ghostheart5/fantastic-guacamole/pull/160) remained open and unmerged.
- Local branch `codex/axiomara-3102-release-prep-20261002` preserves the original branch and contains a conflict-free merge of current `origin/main` that remains **uncommitted**. Its two staged files are the candidate builder and its tests. The additional repairs described below remain local and uncommitted. No final source commit hash exists for this combined work yet.
- The [3101 candidate build](https://github.com/ghostheart5/fantastic-guacamole/actions/runs/37004098715) succeeded, but its effective profile is internal/contained with public release, billing, cloud sync, analytics and crash collection disabled. It cannot supply public-profile acceptance for 3102.
- The [3100 Android release build](https://github.com/ghostheart5/fantastic-guacamole/actions/runs/36812222428) succeeded. A local publication receipt records October 1 production publication; the current Play Console and non-tester installation were not checked in this preparation.

Verified historical AAB hashes: 3101 `d8e5fff46fd7376aa5b4636752e1c75a5eb183977fb277f953156438bbeb0818`; 3100 `3c1ba68af80536d14a0f81ef47ef281a3e5c7c6e78fe12a25c426a7489274bd1`. Neither identifies a 3102 artifact.

## Prepared changes

1. **Candidate tooling reconciliation.** Incorporated `main`'s source-guard fix in `scripts/android_candidate_build.py` and its tests. Public-capable source can produce a contained internal candidate without weakening the final effective-profile checks.
2. **Tutorial completion.** The guide resolves its exact saved Creator task, including completed tasks omitted from the active list. An already completed target offers an explicit Finish guide action. The milestone requires the exact expected task's saved completed state, verified after Complete or after the explicit Finish guide action for a task already completed. Skip/Postpone and unrelated tasks cannot finish it. Account generation, storage state and task identity are checked around asynchronous work. Missing/unavailable targets retain a pause/restart exit.
3. **Bounded paid-reply recovery.** Successful reply content is settled through the existing atomic TTL overload. Only an authoritative HTTP 404 / `PGRST202` missing-RPC response allows metadata-only compatibility settlement. Ambiguous failures use reconciliation. Duplicate replies are read only for the exact completed account/request, a matching active billing principal and a valid future expiry. Expired or unverifiable cache entries are not returned and do not cause another provider call or debit.
4. **Disclosure and listing preparation.** Updated EN/ES-419 listing drafts, English release notes and the exact-artifact screenshot checklist. Canonical privacy and its three generated copies disclose temporary paid-reply storage and the recovery-window refresh possibility. The Data safety draft distinguishes stored content from ephemeral processing and preserves earlier records as historical.

No database migration or workflow trigger was changed. No backend deployment, live account data probe, credential change, device operation, public policy publication or Play action was performed.

## Local validation

| Check | Result and scope |
| --- | --- |
| Edge Function gate | PASS: format, lint, entrypoint checks and 309 tests across 29 files; zero failures, errors or skips. Includes 51 AI proxy cases. |
| Related Flutter tests | PASS: 109 tests, zero failures, errors or skips, with terminal completion receipt. Covers tutorial, Timeline, AI contract, release/configuration/billing/privacy contracts and legal/router localization. |
| Focused tutorial regressions | PASS: 42 tests, included in the related suite; not an additional independent total. Initial fixture timing/setup failures were corrected and rerun. |
| Python release tooling | PASS: 39 tests across public profile, evidence publishing and candidate builder suites. |
| Source release guard | PASS: version consistency and target API 36 among the enforced checks. |
| Workflow validation | PASS: 15 workflow files. |
| Legal generation | PASS: generator and consistency check; all 14 unrelated generated legal outputs remained byte-identical. After the final wording refinements, all five legal contract tests passed again in `final-legal-flutter-manifest.json`. |
| Static analysis | PASS: `flutter analyze --no-pub --fatal-infos`, no issues, exit 0, 106 seconds. |
| Secret and diff checks | PASS: security secret guard, secret content guard, and staged/unstaged `git diff --check`. |

Local completion evidence is under `.dart_tool/release3102/`, including `edge-functions.junit.xml`, `final-related-flutter-manifest.json`, and `tutorial-fix-r2-manifest.json`. These are ignored local receipts, not hosted CI artifacts. Counts must not be summed where suites overlap.

Independent source review found no actionable tutorial correctness defect. The new widget tests use controlled repositories and a fixed account boundary; they do not directly prove an account switch during an in-flight lookup, real persistence failure, process restart, or signed-device behavior. Backend tests use mocked service responses; they do not prove deployed SQL overloads, permissions, principal relations or cleanup job health.

## Evidence still needed for release

| Required next evidence | Current disposition |
| --- | --- |
| Reviewed committed source on GitHub and protected-branch checks | Pending commit/push/PR approval and hosted CI, database and runtime checks for the resulting exact source. Local repairs are not yet on GitHub. |
| Current production backend parity | Pending authorized inventory and targeted verification. The AI proxy changed, so older parity evidence cannot cover this candidate. Verify the existing TTL overload, principal relationship, cleanup health and deletion handling before considering deployment of the reviewed function. |
| Source and configuration bound acceptance packet | Pending the six real records required by the release workflow: privacy/disclosure, AI safety, provider retention, backend parity, cloud isolation/recovery/deletion, and billing recovery. Do not mark templates approved or reuse stale/cross-source evidence. |
| Signed public 3102 AAB | Missing. Verify final package/version/signature/hash/effective public configuration, native packaging, alignment and 16 KB compatibility evidence, and symbol/mapping availability as applicable. A workflow definition or old AAB is insufficient. |
| Artifact runtime acceptance | Pending authorized test-track delivery and exact installed-artifact checks: EN/ES tutorial and critical flows, accessibility, paid AI interruption/recovery, purchase/restore/refund/pending behavior, cloud isolation/recovery/deletion and reviewer access. |
| Listing and Console parity | Draft text and graphics exist; fresh 3102 EN/ES screenshots and final claim acceptance are pending. Reconcile current hosted privacy, support/deletion services, Data safety and other declarations with the actual distributed behavior and saved Console values. |
| Submission and rollout | Separate exact-artifact, track/country and action approval, followed by verified Console readback. No submission is prepared as an already approved action. |

The existing [release requirement disposition](RELEASE_REQUIREMENTS_20260926.md) governs; this report introduces no blanket paid legal or clinical certification requirement. Current [Google Data safety guidance](https://support.google.com/googleplay/android-developer/answer/10787469?hl=en) requires mapping actual collection and storage. Persistent reply storage cannot be called ephemeral simply because replay expires quickly.

## Next reviewable action

Review the local diff, then obtain approval to commit the prepared branch, push it to the public repository and open a pull request against `main` for hosted validation. The publication request must name this branch and its final file set. That source publication does not itself authorize a merge, production access/deployment, signed build using production credentials, device testing, Pages publication or Play submission.

The public release workflow additionally requires source ancestry from protected `main`, current configuration-bound records and production environment inputs. Its existing privileged backend verifier needs explicit production-access direction. A build or verification must not be used as an indirect backend repair, deployment or public rollout.
