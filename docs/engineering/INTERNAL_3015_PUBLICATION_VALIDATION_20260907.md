# Internal 3015 publication and validation

## Source and repairs

- Version `4.1.0+2026083015`, package `com.ghostheart5.chronospark`.
- Signed-build source: `13ffab3e752468b1944cdb98c2c930e8e5debc99`, pushed on `fix/aab-prebuild-cleanup-20260905`.
- Account setup state now reads the active account's stored completion synchronously once preferences are initialized. Returning to a completed account and legacy ownership refresh no longer introduce a loading interval. Both regression assertions failed before the repair; seven onboarding/provider tests passed afterward.
- Explicit navigation always requests the destination stack from the router. Thirty-four route/shell checks passed. The added replacement-route tests also passed before the change; the exact second-account Moto Back failure still requires live acceptance.
- The compiled internal cohort contains exactly two user-authorized accounts. Policy SHA-256: `f1a0f1ccf32ba0942c127fbd41fba5abaad951b3223e3e8d213fa626719d96b4`. This enables the test surfaces without granting premium access or bypassing purchase verification.

## Host validation

- [CI 34174390179](https://github.com/ghostheart5/fantastic-guacamole/actions/runs/34174390179) passed on the exact source above. Retained manifests show 2,543 unit/widget tests, 15 QA configuration tests, 38 Windows checks, 16 Windows Maestro launcher checks, and 8 Linux app integration tests. These reports contain zero failures, errors, or skips. Static policy, analysis, architecture, release, and coverage gates passed.
- [Backend 34174042088](https://github.com/ghostheart5/fantastic-guacamole/actions/runs/34174042088) passed, including 96 Edge Function tests with no failures or errors. Its source is `f3b628b17edd9b196319aa646c1d0ae2db575a04`; the only difference to the build source is one indentation line in a Flutter test. Backend code is identical.
- [Maestro 34174013478](https://github.com/ghostheart5/fantastic-guacamole/actions/runs/34174013478) passed the 11-flow QA journey suite on `f3b628b17edd9b196319aa646c1d0ae2db575a04`, on Android 15/API 35. App source, Android configuration, dependencies, Maestro flows, and runtime tooling are identical to the build source. The isolated QA runtime does not establish Google Play Billing behavior.

## Signed build and delivery

- [Signed build 34175159500](https://github.com/ghostheart5/fantastic-guacamole/actions/runs/34175159500) attempt 2 passed after the exact-source CI. Attempt 1 stopped at the effective-policy digest guard because an older environment secret overrode the repository cohort secret. The environment secret was corrected to the same two authorized account digests and reviewed policy hash; app source was unchanged.
- Local verification passed at 2026-09-08T01:13:39Z: checksum, signature, package/version, compiled target API 36, billing permission, exact CI/source binding, and two-account test policy. AAB SHA-256: `295ed667ba3a819d056f0c3b6dcf4846357d9dfe136a1afacc7869e6534b8e53`; size 77,759,028 bytes.
- Internal-track publication and Moto update are not complete. Play Console remained behind a loading overlay and then browser control disconnected. The last verified installed version is 2026083014. Version 3016 is being prepared for additional prepaid/credit test support; 3015 evidence does not validate those changes.

## Required device acceptance

- Play update preserves the owner profile, 200 XP, saved goal, note, rhythm, and task history.
- Completed setup remains completed across owner, second-account, and owner sign-ins.
- Settings system Back and header Back work for both accounts.
- Both authorized accounts can access internal billing, while the second account cannot restore the owner's active Google test purchase.
- Returning owner can restore its own purchase and retains its original progress.
- The user's latest instruction explicitly excludes both level-20 endurance and monkey testing, including after other checks pass.

## Billing evidence boundaries

The prior [3014 report](INTERNAL_3014_PUBLICATION_VALIDATION_20260907.md) records live purchase, restore, renewal, expiration, revocation, grace, hold, recovery, pause, and automatic-resume observations, with their timestamps and notification/refresh delays. Those observations are separate from the 3015 host checks. Pending-purchase instruments were not offered by the tested subscription checkout. AI credit spending remains contained; neither case is claimed as a live pass.
