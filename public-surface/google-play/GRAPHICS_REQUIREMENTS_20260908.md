# Google Play graphics: level-20 release preparation

Checked September 8, 2026 against [Google Play preview-asset requirements](https://support.google.com/googleplay/android-developer/answer/9866151?hl=en).

| Asset | Specification | ChronoSpark status |
|---|---|---|
| App icon | 512 x 512, 32-bit PNG, at most 1,024 KB | Existing `assets/app-icon-512.png` verified: RGBA, 425,441 bytes. |
| Feature graphic | 1024 x 500, JPEG or 24-bit PNG without alpha | `assets/feature-graphic-1024x500-rgb.png` is the opaque export of the existing design. Use this copy instead of the older RGBA file. |
| Phone screenshots | At least two screenshots overall; up to eight per device category. JPEG or 24-bit PNG; dimensions 320-3840; longest side no more than twice the shortest. | Eight actual 1080 x 1920 RGB JPEG previews from installed build 2026083018, using the earned level-20 profile. Recapture the repaired build before final listing use. |
| Phone promotion quality | At least four screenshots; 9:16 portrait at least 1080 x 1920, or 16:9 landscape at least 1920 x 1080 | Existing eight-image preview set satisfies these image dimensions. |
| 7-inch / 10-inch tablets and Chromebook | Large-screen guidance: at least four actual screenshots, 1080-7680px, 9:16 portrait or 16:9 landscape | Pending actual supported-device captures. Do not resize phone images into tablet evidence. |
| TV, Wear OS, Automotive and XR | Additional screenshots and some additional graphics apply when distributing to those platforms | No platform-specific release was prepared here; confirm selected form factors in Console before submission. |

## Prepared package

Open `artifacts/google-play/level20-20260908/index.html` for the actual phone-image gallery. `listing-graphics/` contains the icon and opaque feature graphic; `listing-graphics/manifest.json` records dimensions, encoding, hashes and alt text. The icon and graphic do not contain fabricated app UI or progress metrics. The feature graphic retains the existing cyan/gold ChronoSpark planning artwork.

Phone preview order: Profile level 20; Nexus next action; Smart Planner guidance; SI Console evidence; filled Creator task; completed goals; Timeline history; Progression level 20. The profile reached 36,100 XP through ordinary task completions. These captures show build 3018, not the eight repairs awaiting build 3019.

After the Play update, recapture all eight from the same preserved profile. For each supported tablet category, prioritize Profile, Nexus, Smart Planner and Timeline at a genuine tablet layout. Check text clipping, navigation, keyboard and touch targets at capture time. Include SI Console, Creator and Goals if the resulting layouts improve the set. A fresh emulator starts without this phone's local history; enabling cloud sync or copying private app storage is not part of screenshot preparation.

## Evidence and remaining work

The existing icon and feature artwork were visually inspected. The original feature PNG includes partially transparent pixels; its new export is an opaque 24-bit PNG, visually checked after flattening onto black. No screenshot pixels, XP, task counts or account data were edited.

The controlled Play Console tab could not be read: two attempts timed out, including `Emulation.setFocusEmulationEnabled`. Therefore this document does not certify current Console upload slots, selected form factors, draft assets or live listing content. The August 31 Console readback and store-copy files are historical; do not treat their billing or release-state claims as current. No listing upload or publishing action was performed.

Current status: **conditionally ready for asset review**. Final phone recapture and applicable large-screen captures remain after installation of the rebuilt release.
