# Internal build 3019: Play delivery and repaired-device acceptance

September 8, 2026. Result: **PASS for the eight scoped repair checks on the Play-installed Moto**, with the limits below. This is not production approval or a new whole-app endurance certification.

## Exact release and preserved installation

- Package `com.ghostheart5.chronospark`, version `4.1.0+2026083019`, app source `162a852620f05f85ac7580ed945605cab3b9fe67`.
- AAB SHA-256 `f9c6fae3472474696b72e0edae54621f6601c93020c3d9f84d0e07dfbb904652`.
- [Internal release 21](https://play.google.com/console/u/0/developers/7769568821533010883/app/4976364997895633041/tracks/4700889470079224942/releases/21/details), named `2026083019 (4.1.0) - level-20 repairs`, was saved and published. Independent Console readback showed **Available to internal testers** and the exact version code. No production release was made.
- Console showed ReTrace mapping and native debug symbols attached. Supported-device comparison showed zero devices lost. The track's form-factor selector showed Phones, Tablets, Chrome OS and Android XR.
- Moto G Stylus 5G (2022), Android 13/API 33, updated using the Play Store's Update button. ADB independently read version code `2026083019`, version name `4.1.0`, installer `com.android.vending`.
- The signed-in profile survived without uninstall, data clear, storage copying or logout: level 20, 36,100 XP, three-day streak, 1,444 completions before testing. One normal QA completion produced level 20, **36,125 XP**, three-day streak and **1,445 completions**. The creative milestone task remains active.

## Installed repair checks

| Finding | Observed Android result | Evidence in `test-results/internal-3019-device-20260908/` |
|---|---|---|
| DEMO-01, Creator labels | Filled title, description and note-body fields retain their Android `hint` labels. `NAF` alone is not a valid failure here because the dump also exposes the hint. | `demo01-filled-creator.xml`, `demo01-note-fields.xml` |
| DEMO-02, understandable confirmation | Exact review remains; account binding, revision/digest and confirmation-token details are absent. Normal confirm shows `CREATION SAVED` and one saved change; Undo removes the new task. | `demo02-review.xml`, `demo02-saved.xml`, `demo02-undo.xml` |
| DEMO-03, live SI evidence | Without an app restart: goal count 2 to 3; active tasks 1 to 2 after creation, then 2 to 1 after completion; Timeline 1,444 to 1,445. | `demo03-si-before.xml`, `demo03-si-after-goal.xml`, `demo03-si-after-task.xml`, `demo03-si-after-completion.xml` |
| DEMO-04, goal accessibility | Goal title is exposed; Share and Expand/Collapse controls include the exact goal name. Expansion works and linked progress reaches 1 of 1 actions. | `demo04-goals.xml`, `demo04-expanded.xml`, `journal.jsonl` |
| DEMO-05, first guidance tap | A single request tap produces guidance with keyboard closed (0.903 seconds) and open (1.099 seconds). The open-keyboard case starts with `mInputShown=true` and ends with the keyboard dismissed. Make smaller and Different approach produce valid alternatives. | `demo05-keyboard-closed-before.xml`, `demo05-keyboard-closed-result.xml`, `demo05-keyboard-open-before.xml`, `demo05-keyboard-open-result.xml`, `journal.jsonl` |
| DEMO-06, saved-note reader | Existing note opens its reader. New QA note reopens with its exact title/body, including after a cold app restart. Opening it creates no extra note. | `demo06-note-reader.xml`, `demo06-note-with-body.xml`, `journal.jsonl` |
| DEMO-07, old receipt in new draft | Use this plan stages an unsaved Planner draft with no old `CREATION SAVED`, saved-change count or Undo receipt. Discard creates no task. | `demo07-new-planner-draft.xml`, `after-planner-preview-discard.xml` |
| DEMO-08, established Profile copy | `Progress recorded`, actual completion count, level 20 and XP are shown. Old initial-state promises are absent. Profile and note content persist after force-stop/reopen. | `journal.jsonl`, `play-01-profile-level20.xml` |

The automation asserted fresh semantic targets before acting. Runner selector/timing corrections were recovered without duplicate completion or data reset. They are not app defects. The keyboard-open probe explicitly checked the IME rather than inferring it from the screenshot.

## Health and evidence limits

Two bounded app-process health reads reported zero fatal crash-buffer lines, zero recent unhandled exceptions and zero layout-overflow lines. Final process PSS was approximately 256 MiB, battery 100%, temperature 28 C. Android exit history showed the intentional Play-update stop and our intentional cold-reopen stop; no crash or ANR exit was observed in this session window. Display size was restored to physical 1080x2460 and notification visibility restored after captures.

These are targeted physical-device acceptance checks, backed by the already-passing [exact-source CI](https://github.com/ghostheart5/fantastic-guacamole/actions/runs/34249838972): 2,586 Linux Flutter tests, 15 configuration tests, 41 Windows screen/golden tests, 16 Windows Maestro launcher contract tests and eight Linux integration tests, plus required static and coverage checks. The previous local Windows full run passed 2,587 tests. No source changed during this delivery/acceptance phase, so those suites were not redundantly rerun.

TalkBack spoken output was not manually certified; the device check verifies accessibility metadata and actionable controls. Timeout/error/race cases and milestone invalidation remain host-regression evidence rather than newly injected Android failures. No monkey test, new level-20 grind, real payment or new subscription lifecycle was run in this phase. Previous billing results do not certify a future changed credit policy.

## Final phone assets

Eight actual 1080x1920 RGB JPEG captures from installed build 3019 are in `artifacts/google-play/level20-20260908/installed-3019-verified/`. They show Profile, Nexus, Planner, SI, Creator, Goals, Timeline and Progression using the preserved level-20 profile. UI and XP were not generated or composited. The Creator image is an unsaved form, not an extra saved task. The screenshots include real QA/demo records; they are prepared for review, not uploaded to the public listing.

The older build-3018 previews remain historical. Icon and opaque feature graphic are included separately. Actual tablet/Chromebook/XR layouts and applicable category assets remain pending; phone images are not evidence of those layouts.

## Monetization boundary

Internal delivery and repair acceptance are complete. Public monetization remains contained. Live readback confirms the current free-daily versus paid-monthly/yearly allowance mismatch; see [the cost and policy review](MONETIZATION_POLICY_REVIEW_20260908.md). No catalog allowance, wallet, public availability or subscription price was changed in this phase.
