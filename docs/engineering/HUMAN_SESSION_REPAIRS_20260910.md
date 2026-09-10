# Timeline and realistic-session repairs

This change normalizes Timeline display and day comparisons to the device timezone, repairs six findings from realistic emulator use, and makes installed QA progress durable across process restarts.

- Ordinary third-person family wording no longer establishes a self-harm concern without relevant concern language.
- Planner follow-up confirmation and localized safety copy use the same bounded conversation context as execution.
- Explicit note time limits and number-word work windows constrain plans; generic request words no longer outrank the requested course subject.
- Timeline's task goal selector fits long titles within the editor width.
- SI uses an available optional decision receipt, bounds source reads, and recovers the input after a stalled query deadline.
- The navigation shell retains its shared decision subscription across covered routes.
- Installed QA uses durable secure storage while generic mock host tests retain memory storage.
- Maestro helpers account for keyboard and review-panel scroll positions while preserving required assertions.

Pre-commit validation completed 2,847 Flutter executions: 2,844 passed, with three initial failures repaired and passing in a 40-test rerun. Static analysis and scoped formatting passed. The initial failures were two route-fixture deadline-cleanup errors and the Planner responsibility line limit. Exact logs remain in `test-results/human-repairs-20260910/`.

The repaired x86_64 QA APK has SHA-256 `da25db96e0b29d1b06a59d4ae6698a06d22e01501018829fa33ac1145a9dea09`. A 17-minute emulator replay verified both previously stalled SI inputs, ordinary-family and supportive-follow-up requests, selected-note constraints, long-title editing, and three Note/Back/Goals cycles after restart. One simulated task completion awarded 25 XP; 25 XP and a one-day streak persisted after force-stop and same-account login. Existing goals, notes, task links and Timeline history remained intact.

No Flutter failure markers, crashes or ANRs occurred in that replay. Two native startup diagnostic types remain recorded: ashmem pinning deprecation and a resource-package lookup message. Their library origin was not isolated and no functional failure was observed. This is not a claim that every Android log entry is clean.

The emulator artifact uses isolated QA authentication and deterministic local intelligence. It is not evidence of signed-release behavior, live billing, remote AI, deployed backend, physical-device acceptance or Play approval. No monkey or level-20 endurance test was performed in this repair replay. Post-commit release gates must report their own exact commit and results.
