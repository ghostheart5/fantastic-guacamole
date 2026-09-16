# Internal 3018 prepaid allowance and Settings repair

Prepared after the live failures recorded in the 3017 acceptance report. Public launch containment remains closed. This candidate is for the existing internal track and two authorized accounts only.

The proposed database migration adds a separate prepaid grant cause and unique purchase-token index while retaining the global unique-order guard. The reconciliation branch requires active, non-renewing Google authority, the exact monthly prepaid test base plan, and Google's verified test-purchase marker. It fills the 300-credit allowance once without requiring predecessor lineage. It does not rewrite any existing wallet or grant. Edge handlers now pass those fields from the Google response. Ordinary production grant rules are unchanged.

RTDN cancellation handling accepts Google's already-expired terminal snapshot and standalone canceled pending purchases. Linked predecessor authority remains separate; contradictory active/pending states still fail. The core fix was deployed as RTDN v16 and recovered the observed failed notification. Subsequent prepaid metadata changes and the database migration have not yet been deployed at this checkpoint.

Settings status copy now follows actual internal credit availability. Toggle rows merge their label and switch semantics, and a label tap changes the control once. The regression checks both label and switch taps and the accessible name.

Local checks: 99 Edge Function tests, six catalog checks, 24 Settings/credit-panel tests, targeted Dart analysis, and migration replay policy pass. The new 15-case database regression and full hosted candidate checks remain pending. The original toggle test needed a visible scroll position and correctly scoped semantics cleanup; the repaired test passes without weakened assertions.

No monkey or level-20 tests are part of this work. No all-pass or production-readiness claim is made.

The first hosted database run (34186433691) failed. It caught replacement of the public compatibility wrappers and a test fixture that gave successive unrelated tokens the same binding timestamp. The migration now replaces only the two underlying phase8_base functions, preserving the wrappers and their grants. The fixture gives successive purchases ordered binding times, and three additional assertions ensure negative cases reach reconciliation. No failed migration was deployed. The complete database suite must pass before deployment.

## Backend and device follow-up

Database run 34186848696 passed all 341 pgTAP assertions plus 99 Edge tests. Before deployment, both underlying production function bodies matched the proposed definitions with only the intended prepaid additions removed. The migration was deployed; the two public wrapper definition hashes remained unchanged. Receipt v20 and RTDN v17 were deployed and all five files per handler matched the tested source. Authentication settings were retained.

Fresh slow-decline notifications processed at 04:26:11Z and 04:26:14Z without errors. Restart and Restore did not activate access or grant credits. On the subsequent slow-approve purchase, restart/Restore explicitly displayed pending at 04:33:53Z while the backend remained inactive with zero credits and zero prepaid grants. It then activated with exactly one 300-credit prepaid grant. A real synthetic one-credit call reduced the balance to 299; replay and active Restore preserved 299 and one grant. At 04:39:30Z expiry had restored the configured free wallet (20 credits), with inactive access and one historical prepaid grant.

Second-account synthetic spending moved its server balance from 20 to 19 with one completed request; the owner remained at zero with eleven earlier completed requests. Consent was restored off, and the owner returned directly to Nexus at level 2. SI Console returned an on-device, source-aware answer at zero credits without external-AI consent.

Live completion also exposed a pending result message persisting after activation and the server's premium_monthly wallet being labeled free. The pending receipt now clears when active authority changes; server paid tiers normalize to the UI's premium tier, and paid allowance copy says period ends. The 22 paywall/wallet tests, 16 Settings tests, and targeted analysis pass. New exact-source hosted gates and final 3018 Play-device acceptance are required for these final display changes. No 3018 AAB had been built when these changes were made.

The remaining Moto walkthrough verified the saved note visually, saved Daily Rhythm state, both linked completed goal actions, eight historical Timeline events, Profile 200 XP/level 2, owner Settings header Back, local Smart Planner guidance, and all three forecast horizons. The 90-day forecast displayed a raw insufficientEvidence enum; its UI label now reads insufficient evidence. Existing Trajectory unit/integration checks and targeted analysis validate that copy-only correction. No tasks were completed and no progression was accumulated during this walkthrough.
