# Internal 3014 publication and validation

## Candidate and repair

- Version `4.1.0+2026083014`; package `com.ghostheart5.chronospark`.
- Candidate source `8686c91d7d91432453cc2ab76fcd3900c03b23d3`, committed and pushed to `fix/aab-prebuild-cleanup-20260905`.
- A same-account authentication refresh could recreate the storage scope object and reload the completed-onboarding provider. The route guard interpreted the resulting loading state as incomplete setup. The Moto reproduced a setup interruption during navigation; continuing returned to Nexus.
- The provider now selects the writable account namespace. Equivalent same-account scope emissions retain completion. Changing accounts or entering unsafe storage still invalidates completion immediately.
- The regression failed before the repair (`Expected: true; Actual: null`) and passed afterward, including switching to another account, returning to the owner, and entering unsafe storage. Six onboarding/provider/return-navigation tests passed. Focused analysis and release/version guards passed.
- Daily Rhythm library, cold goal hydration, Settings Back, and billing runtime repairs from 3013 remain included.

## Automated checks

- [CI 34168129225](https://github.com/ghostheart5/fantastic-guacamole/actions/runs/34168129225): passed. Retained manifests confirm 2,540 Flutter tests, 15 QA configuration tests, 38 Windows checks, 16 Windows Maestro launcher checks, and 8 Linux integration tests, with zero failures, errors, or skips in those reports. Static policy, analysis, architecture, release, and coverage gates passed.
- [Backend 34168129230](https://github.com/ghostheart5/fantastic-guacamole/actions/runs/34168129230): passed, including 96 Edge Function tests with no failures or errors.
- [Maestro 34168256919](https://github.com/ghostheart5/fantastic-guacamole/actions/runs/34168256919) passed Planner and stopped at Creator's time-sensitive assertion. Its screenshot showed the saved task, SCHEDULED marker, and the valid past-schedule description. The test had accepted only the future-schedule description. No app fatal markers were recorded.
- Harness-only commit `e8a197e7a4556be7fe8e5b488bf0726afd0eaf81` accepts both supported open scheduled-task descriptions in the three affected flow files. It retains task-title assertions and matches the observed Creator node exactly once. All 28 YAML contracts passed. The app source is unchanged from the signed candidate.
- [Maestro 34169295729](https://github.com/ghostheart5/fantastic-guacamole/actions/runs/34169295729) stopped at Planner's Evidence visibility assertion. The captured screen showed the completed plan and its Use this plan action, with the follow-up keyboard leaving lower actions outside the viewport. The harness now scrolls Evidence into view before asserting it; it retains the assertion. All 28 YAML contracts passed.
- Harness commit `d9af132ebe984ca07e8702279f296f0c65f371de` is pushed. Its cumulative difference from signed source is limited to four Maestro YAML files; no app source changed. [Maestro 34170532671](https://github.com/ghostheart5/fantastic-guacamole/actions/runs/34170532671) is running all 11 QA journeys. No completed 3014 full journey pass is claimed yet.
- Superseded 3013 run 34165841920 attempt 2 was canceled when the 3014 suite started. Its retained Creator log reached the saved-goal assertion after a cold restart. It did not produce a complete suite result and is not a passing full run.

## Live billing observations on installed 3013

- Annual subscription restore reported active, consistent with backend readback at 22:52:39 UTC.
- Annual expiration was recorded at 22:57:27 UTC and reconciled by the backend at 22:57:30 UTC. The foreground app removed active access and enabled plan selection by 22:58:03 UTC without a tap or restart. The prior observation at 22:56:49 UTC was active.
- At 22:58:55 UTC, a monthly purchase using `Test card, approves then charges back` returned Google's subscribed confirmation. The checkout explicitly said this was a test subscription with no charge. The app and backend then showed activation. Subsequent events were recorded as unsupported/ignored. Their timing and instrument suggest pending refund reviews, but the inbox omits the original payload, so the exact type is an inference. Google's [RTDN reference](https://developer.android.com/google/play/billing/rtdn-reference#pendingrefundreviewnotification) distinguishes pending review from completed revocation. A developer review-response workflow remains unimplemented.
- The test subsequently generated processed voided-purchase events at 23:05:52 and 23:11:00 UTC. Backend readback confirmed `revoked`, inactive, and nonrenewing; the foreground app removed active access. Restore afterward reported `No active purchases were found to restore.` This establishes chargeback revocation and restore protection for this test purchase, separately from the unimplemented review-response workflow.
- A fresh monthly purchase with `Test card, always approves` and the explicit no-charge disclosure activated successfully. Backend readback at 23:15:56 UTC confirmed active/renewing, with expiry 23:19:50 UTC. This new test subscription is the upgrade-preservation target.
- These are installed-3013 and deployed-backend observations, separate from 3014 host checks.

## Signed release and Moto validation

- [Signed build 34168999990](https://github.com/ghostheart5/fantastic-guacamole/actions/runs/34168999990) passed after exact-source CI. Local verification passed at 23:19:51 UTC: checksum, source/build/CI binding, upload signature, compiled manifest, and internal billing configuration. The 77,758,666-byte AAB has SHA-256 `02976d04f7888fb22ef1bbfbd68bc0ce566daffdba3aef304a46a0bfecbd09e0`.
- Google Play internal release 18 was observed available to internal testers at 23:22:20 UTC. Only 3014 was included, with no reported supported-device reduction. No production release was published.
- Moto installed the update through Google Play at 23:22:34 UTC. Package readback confirms version 2026083014, target SDK 36, and installer `com.android.vending`; local data was preserved.
- Saved goal and note remained visible after the update. The renamed Daily Rhythm remained active and completed for the day, with duplicate completion and skip disabled.
- Settings opened directly after update and after a cold restart. Manage plan and credit routes returned to Settings. The monthly subscription stayed active across the update, and Restore confirmed active access. Backend readback at 23:35:44 UTC confirmed the current monthly renewal was active through 23:39:50 UTC.
- A new 15-minute task, `QA confirm saved rhythms and goals after update`, was linked to the preserved goal, reviewed and saved once, then completed once through Nexus. XP increased from 175 to 200. After cold restart, Profile retained 200 XP and Timeline showed exactly one completion for this task among five events.
- The retained Android crash buffer since the update contained zero ChronoSpark fatal exception records at 23:36:23 UTC. This is a bounded crash-buffer observation, not proof of every possible runtime error. No forced live auth-token refresh was induced; the provider regression covers the specific same-account scope refresh mechanism.

## Remaining evidence limits

- Grace/hold/recovery requires the outstanding manual test-payment change; live ownership isolation requires a second authorized account. Unexecuted cases remain unverified.
- Automatic approval review blocked the Google subscription-management action and gave only `blocked by policy` as its reason. The user was given the manual Google Play steps; the blocked action was not retried through an equivalent route.
- AI credit spending remains contained. No token-spending pass is claimed.
- The preserved Moto profile is level 2, 200 XP, two-day streak. Level-20 endurance has not started because material prerequisites remain incomplete. Monkey testing is excluded by request.
