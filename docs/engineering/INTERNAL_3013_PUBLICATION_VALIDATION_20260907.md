# Internal 3013 publication and validation

## Release identity

- Version `4.1.0+2026083013`; package `com.ghostheart5.chronospark`.
- Signed app source `4b32d741a6e90bb753bc75c457a6aeda1fbb1b54`.
- [Signed build 34165716694](https://github.com/ghostheart5/fantastic-guacamole/actions/runs/34165716694) passed using the existing upload signing identity and frozen build tooling `b6a05bad6a8646e022b0ffbb06720070e3bca0f8`.
- AAB SHA-256 `8009a7a9e25fb2a2cb10ef6bf4751f866269d2ccd4cb852c182d0d24db26c110`; 77,748,859 bytes.
- Download checksum, JAR signature, upload certificate fingerprint, compiled package/version/SDK manifest, source/CI binding, and internal billing configuration were verified locally. The existing self-signed upload certificate warnings do not change the successful signature verification.
- Google Play internal release 17 was observed available to internal testers on September 7, 2026 at 22:23:48 UTC. Console preview reported no reduction in supported devices. Only version 2026083013 was included.
- Signed bundle and verification files remain in `artifacts/releases/4.1.0-2026083013-internal-billing-verified/`.

## Repairs

- Creator now provides a Daily Rhythms library. Existing services handle period completion/skip, pause/resume, rename, and confirmed removal. Recorded period outcomes disable duplicate completion/skip. Dialog mutations recheck the current account before writing.
- Account initialization prepares the scoped goal box before allowing synchronous goal reads. It rechecks the authentication generation after preparation. Cold goal saves and deletes open storage before reading existing records, preserving unrelated goals.
- The account-transition widget fixture now uses its in-memory storage preparation seam; real close/reopen tests separately verify scoped goal persistence. A two-minute fixture timeout bounds future stalls.
- Settings Back navigation and the internal subscription runtime repairs from earlier releases are included.

## Automated evidence

[CI 34164958212](https://github.com/ghostheart5/fantastic-guacamole/actions/runs/34164958212) passed for the signed source:

- 2,539 Flutter tests and 15 QA configuration tests; zero failures, errors, or skips.
- 38 Windows checks, 16 Windows Maestro launcher checks, and 8 Linux app-root integration tests; retained reports passed.
- Static policy, architecture, release, and coverage contracts passed.
- [Backend 34164959324](https://github.com/ghostheart5/fantastic-guacamole/actions/runs/34164959324) passed, including 96 Edge Function tests with no failures/errors.

Focused local evidence includes 20 Creator/rhythm/provider/coordinator tests, 29 goal-storage/account-boundary tests, and 12 account-startup widget checks. Focused analysis and 28 Maestro YAML contracts passed.

## Hosted journey evidence

- Run 34163528095 passed Planner input and stopped in the new rhythm flow because the scroll gesture began inside the open keyboard. The helper now starts at 55% screen height in the outer gutter. A corresponding keyboard-open Moto gesture reached Creator review and was canceled without saving.
- Run 34164686241 reached the saved rhythm library and displayed the correct title and controls. Its exact standalone-title selector failed because Android merges the card's title, cadence, and status into one accessibility node. The selectors now verify that observed group and retain explicit title, completion status, and disabled-button checks.
- The selector-only commit `ccfd96a02dd71c195524ec5008b605aeea3a8a62` changes no app source from the signed build.
- Run 34165841920 attempt 1 stopped before its first journey behind a Pixel Launcher ANR dialog. ChronoSpark fatal-marker count was zero. This is retained as an infrastructure failure, not a passing run.
- Attempt 2 uses a fresh hosted device and is pending. No complete passing 3013 Maestro suite is claimed yet.

## Device and live billing boundaries

- Moto installed 2026083013 through `com.android.vending` at 22:37:19 UTC, preserving local data and the signed-in account.
- The saved goal returned on Nexus after the update and remained available in Creator's linking dropdown after a cold restart. The saved note remained visible.
- Existing Daily Rhythm readback, pause/resume, rename, removal cancellation, completion, disabled duplicate completion/skip, library reopen, and cold-process persistence passed on the Moto. The rhythm is now `QA rhythm - review test evidence - reviewed`, completed for the current day. An automation cursor-position typo during rename was corrected through the same dialog; no record was removed.
- Restore reported `Subscription restored and active.` Both Manage plan and View credits returned to Settings with hardware Back. Profile readback remained level 2, 175 XP, two-day streak.
- A further issue was reproduced: a same-account state refresh can put completed onboarding into a temporary loading state, sending navigation through setup. The added provider regression failed with `Expected: true; Actual: null` before repair. Build 3014 selects the writable account namespace to prevent reloads for equivalent scope objects, while real account changes and unsafe storage still invalidate completion. This fix needs its own signed build and device verification; 3013 is not the final passing candidate.
- The preserved profile is level 2 with 175 XP and a two-day streak. Upgrade checks target its saved goal `QA journey - verify release workflows`, rhythm `QA rhythm - review test evidence`, and note `QA note - internal release checks`.
- Earlier live monthly/annual approval, decline, canceled checkout/retry, restore, renewals, and monthly foreground expiration results remain documented in the 3012 report. They do not establish every lifecycle case on 3013.
- Grace/hold/recovery still require the requested manual test-payment-method change. Live ownership isolation still requires a second authorized account. Pending purchase, pause/resume, and chargeback were not all available or executed. Unexecuted cases are not passes.
- AI credit spending remains contained. No successful token-spending test is claimed.
- Level-20 endurance has not started because material live prerequisites remain incomplete. Monkey testing is excluded by request.
