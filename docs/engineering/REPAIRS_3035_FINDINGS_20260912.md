# Repairs for the six build 3035 exploratory findings

September 12, 2026. **All six findings repaired in source; local validation PASS. Ready for commit/rebuild and subsequent installed-device confirmation.**

These changes address the six reproduced findings in [the internal test report](HUGE_3035_INTERNAL_TEST_20260912.md). The tested Play installation remains build 3035; source repairs do not establish repaired-device or signed-release validation.

| Finding | Repair | Regression evidence |
| --- | --- | --- |
| F01: SI ordinary question forms | The bounded listing recognizer accepts current goals and questions asking which goals/tasks/milestones the user has. Next-action recognition accepts the natural small-bookkeeping-action question after the school-pickup context. Unsupported weather/place tests remain in place. | Exact failed questions, saved task/goal readback, empty milestones, ordinary next-action variations and unsupported-topic controls. |
| F02: recovery exceeds total time | A saved-task minimum splits its existing total block between setup and rest. A one-minute block is entirely recovery. Other recovery options explicitly include reassessment/planning inside their total; generic recovery no longer adds a fixed five-minute break outside its estimate. | One-, three-, five- and ten-minute follow-ups; parsed setup plus rest equals the option total; all options fit the limit; no repository writes. |
| F03: invisible rhythm increase icon | The filled increase button uses an explicit dark foreground on the established cyan fill. Its action and target bounds are preserved. | Actual app-theme widget contrast is at least 3:1; the existing cadence/target submission journey still increments and saves correctly. |
| F04: linked skipped rhythm blocks task | A note's rhythm link is a fallback when no task/goal is focused, rather than an unconditional override of matched work. Explicit rhythm requests still retain the existing period-state guard. | Both skipped and unrecorded linked-rhythm cases preserve the active receipt task and the selected note's seven-minute limit. All rhythm period-state regressions remain covered. |
| F05: recovery completion targets an unrelated task | Task timing and completion controls appear only when the displayed recommendation names the block's task and its decision identity matches. Recovery, reconciliation and a different task identity do not borrow another block's completion action. | Rendered Nexus tests cover ordinary task, canonical `Work on:` task, recovery, and a different task ID with the same title. |
| F06: empty milestone health | Progress review receives the actual milestone count. Zero records produce an unavailable-health statement instead of an on-track or poor-execution rating. | Empty-count summary plus provider-level empty-milestone readback; existing nonempty/source-health regressions. |

## Validation

- Focused suite: **126 passed, zero failures/errors/skips**, terminal success independently parsed. Includes the existing Nexus golden comparisons and Creator form journeys.
- The first focused attempt failed on two new test assumptions: expecting a five-minute fallback when the actual low-energy estimate is three, and assuming a task title appears only once on Home. The title assertion now targets the decision text specifically; completion visibility and identity assertions were not weakened. Both attempts remain retained.
- Broader related suite: **283 passed, zero failures/errors/skips**, terminal success independently parsed. Covers SI engines and screens, Nexus, Creator, Progression, Smart Planner screen/controller and related decision/vitals providers. This overlaps the focused suite; the counts are not additive unique coverage.
- Full `flutter analyze --no-pub --fatal-infos`: **PASS, no issues**. Its first run identified one redundant import in the new Nexus test; removing that import resolved it.
- Non-writing repository formatting check: **PASS, 1,192 files checked, zero changes**. The first run flagged one mixed-line-ending paywall test whose Git content was unchanged. Its line endings were normalized; independent Git comparison remained empty. No paywall test behavior or assertions changed.
- Patch whitespace check: **PASS**.
- Final receipt: `test-results/repair-3035-findings-20260912/verified-results.json`, including raw result hashes, changed-file hashes and the source/test patch hash. Base commit `f4dd5cc2c7f43af73ff0776ff9a3c33cf9c0041b`; source/test patch SHA-256 `a4389c18cc660a81defd680d14b615e1d6a535dde82c16223ce31d0614490f0b`.

Evidence is retained locally under `test-results/repair-3035-findings-20260912/`. Source changes are limited to SI query recognition, Planner response/evidence resolution, Nexus recommendation controls, the rhythm increase style, and Progression summary text. Existing listing assets/copy, release artifacts, backend code and owner data were preserved.

This checkpoint does not commit, push, build a new distribution artifact, publish a release, or claim that the six original device findings have passed on a rebuilt installation. The next device validation should repeat the exact failed scenarios against the new installed version.
