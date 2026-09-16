# Installed ChronoSpark 3032 validation - September 12, 2026

**Named installed-device checks PASS; production gates remain OPEN.**

The Moto's installed package was independently verified as Google Play delivered
`com.ghostheart5.chronospark`, version `4.1.0+2026083032`, installer
`com.android.vending`. Its signed app source is
`91d9086ea76ecb10de74e950be3dabfa964e4043`. The current checkout has no differences
from that source in `lib`, `android`, `pubspec.yaml`, `pubspec.lock`, or `web`.
No new app build is needed for this evidence-only checkpoint.

## Actual device execution

Tests ran wirelessly on the authorized Moto G Stylus 5G (2022), Android 13,
owner Android user 0. This was agent-driven use of the installed app with UI
readback, screenshots and runtime logs; it is not independent participant UAT.
No account change, uninstall, sideload, data clear or owner-phone Monkey occurred.

| Area | Result and evidence boundary |
| --- | --- |
| SI repaired responses | PASS 6: five-minute school-pickup action, unsupported weather, goals, tied goal attention, tasks and absent milestones. Weather no longer receives the unrelated task recommendation. |
| Energy and Clarity | PASS 4 boundary combinations: (energy, fatigue, clarity) = (0,0,100), (100,100,0), (10,90,10), (90,10,90). Home and recalculated Trajectory agreed; original unmeasured state restored. |
| Momentum | PASS across 7, 30, 90 and restored 7-day horizons. Home and Trajectory displayed BUILDING on the existing dataset. This establishes displayed-category agreement, not every possible trajectory input. |
| Navigation | PASS 100 targeted root-navigation actions over 25 cycles in 32.12 seconds. Five PSS samples ranged from 206,491 to 219,942 KB; this short sample is not a lifetime memory-leak test. |
| Emotional-state controls | PASS all 9 states and clear. Existing emotion-sharing consent remained off, and unavailable cross-surface sharing was correctly disabled. Enabled sharing was not exercised. |
| Smart Planner scenario | PASS exact five-minute school-pickup/bookkeeping input; Get guidance, Make smaller, Different approach, Why this and Evidence. The explanation identifies saved task/goal context, absent emotion/energy inputs and bounded Daily Rhythm evidence. No plan or entity was committed. |
| Credit spend and retry | PASS actual quoted 3-credit fictional provider request. Balance 517 to 514, included 20 to 17, purchased 497 unchanged, lifetime spent 64 to 67. Independent backend readback confirmed the first charge and zero additional charge on retry. |
| Consent withdrawal | PASS unconfirmed 4-credit quote invalidated and sending disabled when external-AI consent was withdrawn. Original consent restored. No second spend. |
| Subscription display | PASS Free tier and wallet matched the live expired accelerated annual test subscription. No new cash purchase or full subscription-lifecycle rerun is claimed. |
| Restart and progress | PASS force-stop and normal launch: level 20, 36,212 XP and 1,448 completed tasks preserved. Wi-Fi remained enabled. |

The final observed screen was Home. Energy and Clarity were left unmeasured,
Momentum at its original seven-day horizon, and Planner emotion cleared.

## Runtime evidence

The owned filtered ADB collector ran from 07:01:59 UTC to 07:51:01 UTC and was
stopped after checking its process identity. Its 225,457-byte log contains 1,276
lines. The final scan found zero matches for fatal exceptions, ChronoSpark ANRs,
unhandled exceptions, Flutter error markers or RenderFlex/pixel overflows.
This is bounded filtered-log evidence, not a guarantee that every system error
would be captured. Intentional app restart is not classified as a crash.

Log SHA-256:
`d444345a36aa4fb2d8e1caf3c4a248b09594e47c5d109aabe9c91e462a430d35`.

Raw UI observations and scenario receipts remain in ignored
`test-results/stress-3027-20260911/`; names beginning `installed3032`, `si3032`,
`vitals3032`, `momentum3032`, `navigation3032` and `planner3032` identify this
build despite the historical parent directory name. Consolidated, hashed
receipts are in `test-results/release-3032/device/`. No raw account content or
provider response is added to Git by this report.

## Store screenshot candidates

Twenty unedited captures of the installed Play build were visually checked:
four each for phone, seven-inch layout, ten-inch layout, large window and XR
window. Each group includes Home, actual level-20 Profile, Trajectory and Timeline
All history. The Timeline Week view means today plus seven days; an empty future
week is not evidence of missing historical records. All view showed 1,462 events.

These are Android virtual-display layout captures on the Moto, not independent
physical tablet, ChromeOS or XR hardware validation. The package contains true
24-bit RGB PNGs with no alpha and verified dimensions, SHA-256 hashes, alt text,
plus the existing 512-pixel app icon and 1024-by-500 feature graphic.

Package:
`artifacts/google-play/level20-3032-20260911/ChronoSpark-3032-level20-store-candidates.zip`

- 24 entries: 20 screenshots, two metadata files and two branding assets.
- 15,351,424 bytes; ZIP CRC validation passed.
- SHA-256: `ec097b0992bb000a36a36685727217221e9cb733406e4e5d8f6d58c01aa14304`.
- Selected images and metadata: `virtual-layouts/selected-screenshots.json`.
- Four superseded empty-week captures are retained outside the selected folders.

Existing test labels appear in some saved history. These are candidate assets,
not final public merchandising approval. Progress and measured/unknown states
were not fabricated or edited. No screenshot or listing was uploaded this session.
The format review used Google's current
[preview-asset guidance](https://support.google.com/googleplay/android-developer/answer/9866151?hl=en-GB).

## Evidence carried forward and remaining gates

The [main 3032 report](FINAL_3032_RELEASE_VALIDATION_20260911.md) retains the earlier
independently checked hosted suites, native 15-case matrix, strict 16 KB actual
bundle test, 11 Maestro journeys and final five-variant/1,700-event disposable
emulator Monkey result, including failed attempts. They were not rerun on the
owner phone in this checkpoint.

Production remains unapproved and not ready pending:

1. Qualified signed privacy/legal and mental-health/AI-safety review dispositions
   required by this project's release register.
2. Separate reviewer-profile setup and actual restricted-feature journey. Fresh
   Android user 11 readback still reports `user_setup_complete=0`; provisioning
   an account is not successful reviewer access. Owner user 0 was preserved.
3. Public privacy text, Data safety, listing copy and final paid-feature eligibility
   reconciliation. Previously verified public privacy still differed from the
   signed app's provider disclosure; public listing still said No data collected.
   Those public surfaces were not changed or freshly rechecked in this checkpoint.
   Optional Android speech-provider handling also lacks device evidence here.
4. Google's production-access application and approval, and final public asset
   selection. Dimension-valid virtual-display assets do not establish all hardware
   compatibility or approve public release.

Public paid features remain contained pending these decisions. The app policy
remains no ads and no watching ads for credits or access. Finite passing checks
cannot establish that every feature, input, network or future provider state is
error-free. No Google Play production publication was performed.
