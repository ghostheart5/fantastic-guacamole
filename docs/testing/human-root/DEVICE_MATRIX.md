# Human Root device matrix

Version: `1.0.0`
Default state for every row: `NOT RUN`

Use the exact candidate binary recorded in the passport. Record actual device
model, build number, OS patch level, display resolution, logical size, density,
orientation, locale, timezone, and all accessibility settings. A simulator or
emulator complements but never replaces the required physical-device row.

| ID | Device class | Required OS | Logical target | Required coverage |
|---|---|---|---|---|
| DEV-A29 | Isolated Android emulator | API 29 or the oldest supported API | 360 × 800 portrait | Core journey, lifecycle, offline, migration, auth/session |
| DEV-A34 | Isolated Android emulator | API 34 | 412 × 915 portrait | All root arrivals, notifications, permissions, timezone/clock |
| DEV-A37 | Isolated Android emulator | API 37 when supported by the candidate | 360 × 800 portrait | Release-smoke compatibility and rotation |
| DEV-PHYS | Physical low/mid-tier Android | Supported current production API | Record actual screen/refresh rate/storage | Core journey, performance observation, background/kill/restart, permissions, low storage |
| DEV-A11Y | Any matrix device with assistive settings | Same OS as its base row | Record actual screen | Screen reader, maximum text, high contrast, reduced motion, keyboard/switch where available |
| DEV-IOS | Physical iOS device, only when iOS release is in scope | Candidate-supported iOS | Record actual screen | Platform release root, VoiceOver, lifecycle, store/sandbox paths |

## Minimum assignment

- `HR-CORE-001` runs on DEV-A29, DEV-A34, and DEV-PHYS.
- Every root runs once on DEV-A34 and once in DEV-A11Y configuration.
- Interruption cases use DEV-PHYS when the operating-system behavior cannot be
  faithfully induced on an emulator.
- Payment/restore cases use an approved sandbox account on a physical device;
  never a personal or production store account.

## Accessibility configurations

Record each setting as enabled/disabled and the platform value:

- Screen reader: TalkBack or VoiceOver.
- Text: system maximum supported scale and, separately, default scale.
- Display: high contrast/color correction where supported; do not rely on color
  meaning alone.
- Motion: reduced motion/animation scale reduced.
- Input: hardware keyboard, switch access, or equivalent where supported.
- Orientation: portrait and landscape rotation where the root supports it.

## Device preparation

- Use only a clean, isolated test profile. Record storage free space before the
  run and retain enough space for screenshots, video, and logs.
- Disable personal notifications and unrelated accounts. Do not capture other
  applications in recordings.
- Install the exact signed candidate once per passport. Record the installer
  source and SHA-256 in the passport.
- Device restart, process kill, permission changes, time changes, and network
  changes must be restored after the case; record restoration evidence.
