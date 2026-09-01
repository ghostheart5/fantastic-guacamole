# ChronoSpark Production-Candidate Plan

Updated: 2026-09-01T08:18:51-05:00

## Safety boundary

- Candidate checkout: `C:\Users\keegan radetski\ChronoSpark-production-candidate-20260901`
- Candidate branch: `codex/production-candidate-20260901`
- Green base commit: `33a7e39dd3de49b219c0de750bb1fdd31e9d8573`
- The stable branch and the dirty launch-readiness checkout are not build or edit targets.
- No Google Play production upload, public publishing, billing change, credit purchase, key rotation, or customer-data mutation is authorized.
- Live AI testing is capped at 25 requests. One external request may be retried at most twice. One unresolved repair/rebuild failure may receive at most three cycles.
- The already-green full GitHub suite will not be duplicated locally. Only focused checks needed for candidate changes will run locally.

## Ordered milestones

1. Repair the verified secret/configuration blockers and record focused evidence.
2. Commit and push the isolated candidate; require its applicable GitHub checks to pass.
3. Finish preflight: dedicated test account, release inputs, toolchain, API/device matrix, disk, network, and no pending approval.
4. Build the signed release AAB after the final code change, validate it with bundletool, fingerprint it, and generate an APKS archive from that exact AAB.
5. Install only AAB-derived APKs and run focused Maestro, integration, bounded monkey, lifecycle, offline, accessibility, and human-journey testing on available Android configurations.
6. Inspect crash, ANR, Flutter, and serious Android logs; run a bounded soak; repair and rebuild only within the retry limit.
7. Finish the report with exact artifact/commit/checksum/certificate evidence, limitations, reproduction commands, rollback instructions, and live API-call count.

## Current milestone

- The first exact-AAB-derived API 24 pass exposed an Android accessibility bridge defect: the visible login fields did not publish their semantic labels to UI Automator, so release Maestro authentication could not enter credentials.
- `MergeSemantics` now joins each field label with its editable text node, the focused widget test requires the label and `isTextField` flag on the same semantics node, and the focused test passes.
- The earlier AAB from `8bec7af2780f2e2e07d5ea8d2ea724ea317fa5fa` is superseded by this code change. No rebuild may begin until this repair is committed, pushed, and GitHub is green at the new exact head.

## Stop conditions

- Missing signing material, release configuration, dedicated test-account credentials, material product approval, or an unavailable required device/API is `BLOCKED`/`NOT VERIFIED`, never assumed.
- A code change after AAB creation invalidates the artifact and all release-runtime evidence.
- Three unsuccessful repair/rebuild cycles for the same issue end that path.
