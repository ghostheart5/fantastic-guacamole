# Isolated Android layout evidence — September 24, 2026

These are unchanged screen captures from two disposable, headless Google APIs
AVDs. The app was a debug QA APK with synthetic tester access, external AI and
paid checkout disabled. No private account, purchase, or Moto data was used.

| Android | AVD / serial | Captures relevant to the layout finding |
|---|---|---|
| 16 / API 36 | `axiomara_edge_qa_36` / `emulator-5580` | `axiomara-nexus-100.png`, `axiomara-nexus-150.png`, `axiomara-planner-150.png`, `axiomara-planner-bottom-150.png`, `axiomara-si-150.png`, `axiomara-settings-150.png`, `axiomara-nexus-threebutton-150.png` |
| 15 / API 35 | `axiomara_edge_qa_35` / `emulator-5582` | `axiomara-android15-nexus-150.png`, `axiomara-android15-planner-bottom-150.png`, `axiomara-android15-si-150.png` |

[`validation-result.json`](validation-result.json) and
[`android15-validation-result.json`](android15-validation-result.json) bind
the captures to the AVD, APK SHA-256, debug signer, package, version, font
scale, observations, and limitations. Every listed screenshot SHA-256 was
recomputed after copying into this directory and matched its manifest. The
remaining startup/login and three-button transition captures are retained so
the manifests are complete; a transition capture does not prove the screen it
preceded.

The sampled controls show no overlap with the Android status or navigation
areas. This does not prove full-screen coverage, a Play-signed install, or
public AI and billing behavior. The corresponding production gate remains open.
