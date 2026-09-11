# Internal stress pass and replacement candidate 3028

September 11, 2026. This is an in-progress test and repair record, not production approval. Internal delivery is authorized; production publication is excluded.

## Baseline and confirmed findings

The Moto Play installation was `4.1.0+2026083027`, source `faa512ea2e35f229e02da6cdbbcb183f257031c1`. Tests used clearly labeled `STRESS3027` demo records while preserving the existing signed-in level-20 profile.

| Finding | Reproduction and repair |
|---|---|
| Short task duration | Creator offered no duration below 15 minutes. Added 5 and 10 minutes and corrected the singular hour label for 90 minutes. |
| Goal creation history | A confirmed Creator goal appeared in Goals but had no creation event in Timeline. Added idempotent goal creation/undo history without changing the canonical goal ID or awarding extra XP. History failures do not undo a successful goal save. |
| Stale selected-note focus | A retained bookkeeping note outweighed a new explicit family-budget request. Current matching task/goal terms now take precedence unless the person explicitly asks to use the selected note. Constraint words do not identify a task. |
| Requested step duration | A 10,000-task fixture selected the named target but ignored the duration in “Give me a five minute step.” Added request-verb-qualified short-step/session duration parsing; numeric and hyphenated wording are covered. |
| Home task action | “Open TASK” opened blank Creator even when a saved task was displayed. It now opens that task's editor, shared with Timeline; Cancel preserves the task. The Home save rejects account changes while the dialog is open. |
| Rhythm cadence copy | Creator displayed “3 times per weekly.” Labels now use day/week/month. |
| Account-transition runtime errors | All 11 hosted Maestro flows completed their assertions, but the strict log gate found 23 provider errors during logout/account switching. SI and prediction readers now report unavailable evidence before protected storage is ready and discard stale asynchronous account results. Genuine failures in a current account remain errors. |

## Evidence and boundaries

- Fresh baseline CI [34623980203](https://github.com/ghostheart5/fantastic-guacamole/actions/runs/34623980203), database [34623983121](https://github.com/ghostheart5/fantastic-guacamole/actions/runs/34623983121), and native/Windows/strict-16KB [34623986081](https://github.com/ghostheart5/fantastic-guacamole/actions/runs/34623986081) completed successfully. Artifact archives were independently SHA-256 checked. Linux Flutter evidence contains 2,888 passing cases; Windows full-suite evidence contains 2,891, with no skipped cases or reported test errors. These certify the baseline source, not this repair commit.
- Baseline Maestro [34623988287](https://github.com/ghostheart5/fantastic-guacamole/actions/runs/34623988287): 11/11 UI flows, zero JUnit failures/errors/skips, but **overall FAIL** due to the account-transition runtime errors. Do not reinterpret this as a passing release gate.
- Moto energy/fatigue endpoints and opposite combinations were saved and read back on Home and Trajectory, then cleared. Home and Trajectory retained the same values after recalculation.
- 100 targeted rapid navigation events completed, with endpoint checks and memory samples. This is not random Monkey coverage.
- A 1,152-character note was entered in checked chunks, previewed, saved, and undone. An earlier unpaced ADB text burst inserted only a prefix; this was an input-automation limitation, not established app data loss.
- A test rhythm was created with a weekly target of three, marked complete once, paused/resumed, and renamed. Duplicate completion was disabled. Existing rhythms were unchanged.
- One newly created test task was completed: profile changed from 36,137 XP / 1,445 completions to 36,162 XP / 1,446 completions; level 20 was preserved. Home selected another active task and showed updated learning feedback.
- SI selected the budget task from a real-life query. An adversarial request to delete goals and buy credits was rejected as unsupported; the wallet remained at 417 credits. Appearance and audio switches changed and were restored.
- Google Play showed the license-test disclosure and test payment methods. A monthly subscription attempt using the always-declines instrument was declined. Final entitlement readback and subsequent billing cases remain part of the ongoing device matrix.

Detailed local observations, regression output, hashes and runtime logs are under `test-results/stress-3027-20260911/`. The long Maestro artifact was retained under `C:/cs-evidence/stress-3027/` to avoid Windows path limits. Existing release artifacts remain preserved.

## Remaining before acceptance

Complete the final repaired-source suites, commit/push, build and verify signed candidate 3028, publish only to internal testing, update through Play, and repeat installed repair checks. Run the optional five-variant Monkey matrix on the disposable hosted QA emulator. Continue the bounded human/billing/offline/restart matrix and record any new findings. No claim covers every possible input, device, service failure or future execution.

Qualified external review, reviewer-device access and the separate public-paid/store declarations remain governed by the existing release-gate record; an internal build does not close those production gates.
