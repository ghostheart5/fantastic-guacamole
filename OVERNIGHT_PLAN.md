# ChronoSpark Production-Candidate Plan

Updated: 2026-09-01T10:20:00-05:00

## Safety boundary

- Candidate checkout: `C:\Users\keegan radetski\ChronoSpark-production-candidate-20260901`
- Candidate branch: `codex/production-candidate-20260901`
- Tested app-source commit: `9b5d0aa925f64d979fa8873172a58d116cd8c048`
- The stable branch and the dirty launch-readiness checkout are not build or edit targets.
- No Google Play production upload, public publishing, billing change, credit purchase, key rotation, or customer-data mutation is authorized.
- Live AI testing is capped at 25 requests. One external request may be retried at most twice. One unresolved repair/rebuild failure may receive at most three cycles.
- The green GitHub suite is not duplicated locally. Local validation remains focused on changed behavior and release-device evidence.

## Completed milestones

1. Repaired the verified secret/configuration and release-workflow blockers without exposing secret values.
2. Created one isolated, auto-confirmed production Supabase Auth tester and stored its generated credential only in Windows Credential Manager.
3. Pushed the isolated candidate. PR #83 is open, clean, mergeable, and all 10 applicable checks pass at `9b5d0aa9`; Supabase Preview is intentionally skipped.
4. Completed toolchain, signing, environment, disk, network, API 24, and API 37.1 preflight.
5. Built and bundletool-validated the final signed AAB from clean commit `9b5d0aa9`, then generated and installed APK splits from that exact AAB.
6. Ran focused release-device checks: first launch, onboarding handoff, lifecycle, force-stop/reopen, airplane-mode/reconnection, native accessibility inspection, bounded soak, Logcat review, and five Monkey stages on both API 24 and API 37.
7. Stopped authenticated and AI/SI journeys after the same minimum-API login accessibility failure survived the three permitted repair cycles.

## Final decision

- The exact signed AAB and AAB-derived APK installation are verified artifacts.
- The candidate is **NOT VERIFIED FOR PRODUCTION** because API 24 does not expose usable native labels/identifiers for the two login fields. Real release authentication, session/storage, authenticated navigation, persistence, and AI/SI journeys therefore remain unverified.
- No fourth login repair or credential-entry retry is permitted under the task boundary.
- Independent device tests completed safely; no additional app-source change or rebuild is planned.

## Stop conditions reached

- Three repair cycles were exhausted for the API 24 login accessibility failure.
- A physical phone is not attached, so physical-device release behavior remains `NOT VERIFIED`.
- Google Play Internal Testing was not uploaded or exercised.
- Stable/main remains untouched; PR #83 remains open rather than merging into the protected stable branch.
