# Human-Like E2E Testing Plan

Date: 2026-07-24
Scope: ChronoSpark human-like end-to-end validation

Use Flutter integration_test for official full-app testing, then add Patrol or Maestro when you want tests that act closer to a user pressing buttons, typing inputs, and handling native dialogs.

## Human-like smoke flows
- [ ] Launch app -> verify Nexus visible.
- [ ] Tap Add -> type task -> save -> verify task visible.
- [ ] Tap task -> complete -> verify log created.
- [ ] Open Plan -> add/edit time block -> verify no overlap crash.
- [ ] Open SI Console -> type command -> submit -> verify response or safe error.
- [ ] Open Smart Coach -> press Android back -> verify Nexus visible.
- [ ] Open Settings -> change preference -> restart -> verify preference persisted.
- [ ] Trigger premium gate -> verify clear upgrade path, no angry popup.
- [ ] Use small-screen emulator -> verify buttons remain tappable.
- [ ] Deny notification permission -> app still works.

## Automation tool decision

| Tool | Best use for ChronoSpark |
|---|---|
| Flutter integration_test | Official full-app tests that run on device/emulator and use flutter_test-style APIs. |
| Patrol | Flutter-native E2E tests plus native UI interactions like permission dialogs and notifications. |
| Maestro | YAML user-flow scripts that are easy to read and great for smoke paths. |
| Firebase Test Lab | Device matrix and pre-release testing when you are ready to scale testing. |

## Execution notes
- Record device, OS version, and app build for each run.
- Attach screenshots/video for failures, especially navigation and permission flows.
- Any crash in Smart Coach -> Back or task lifecycle is release-blocking.
- Mark each unchecked item only after reproducing pass behavior on at least one emulator and one physical Android device when available.
