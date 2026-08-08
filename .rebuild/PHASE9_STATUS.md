# Phase 9 Status — Docs Refresh (`CHRONOSPARK.md`)

Date: 2026-08-08

## Scope

Phase 9 covers a targeted refresh of `CHRONOSPARK.md` to bring the canonical
product document in sync with the rebuilt codebase after Phases 1–8.

## Changes Made

### 1. Technology Stack (updated)

The stack section was rewritten to reflect the actual `pubspec.yaml`
dependencies:

| Before | After |
|--------|-------|
| Riverpod "with legacy compatibility" | Riverpod v3 with `riverpod_annotation` + `riverpod_generator` |
| SharedPreferences only | Hive (primary) + SharedPreferences (prefs) + `flutter_secure_storage` |
| Orbitron + Inter fonts | Inter only (Regular, Medium 500, Bold 700), bundled locally |
| No backend mentioned | Firebase (Auth, Crashlytics, Analytics, Messaging, Remote Config, Firestore, Storage) + Supabase |
| No routing library | `go_router` v17 with `NavigationShell` |
| No voice/audio | `speech_to_text`, `flutter_tts`, `just_audio`, `audioplayers`, `audio_session` |
| No animations | `lottie` for JSON animations |
| No notifications | `flutter_local_notifications` with `timezone` scheduling |

### 2. Core Layers (updated)

Stale layer descriptions referencing `lib/core/state/app_state.dart` and
`lib/core/si/` paths were replaced with the current architecture:

- **Navigation Shell** — `lib/app/navigation_shell.dart`
- **App Flow Controller** — `lib/state/controllers/app_flow_controller.dart`
- **SI Engine** — `lib/engine/si/si_engine.dart` (with full cognitive stack)
- **State Layer** — `lib/state/` (40+ Riverpod providers)
- **Notification Scheduler** — `lib/system/notifications/notification_scheduler.dart`

### 3. Shell Navigation (rewritten)

The old 5-tab (`Nexus`, `ChronoCreator`, `Temporal Ops`, `SI Console`,
`ChronoLogs`) description was replaced with the actual structure:

- **4 bottom-nav tabs**: Nexus, Trajectory, Ledger, Profile
- **Navigation Map FAB**: Plan, Creator, Milestones, Insights, Settings,
  Smart Coach, SI Console, Progression, Goals, Memories, Soul Map, Timeline

### 4. Premium Gating (updated)

Updated to reflect the `FeatureGate` widget pattern and
`GooglePlayPaywallRepository` / `in_app_purchase` wiring.

### 5. Visual Language (updated)

Corrected font entry: Inter only (no Orbitron); added splash color and accent
color values from the actual theme.

## Protected-File Integrity

All six tracked files are unchanged:

```
OK: CODE_OF_CONDUCT.md
OK: LICENSE
OK: SECURITY.md
OK: README.md
OK: web/privacy.html
OK: assets/legal/privacy_policy.txt
```

## Notes

- All edits are confined to `CHRONOSPARK.md` and this status file.
- No source files, tests, or other documentation were modified.
- The large entity catalog, use-case lists, SI Console reference, and
  subscription system sections in `CHRONOSPARK.md` were not changed — they
  remain accurate design-level documentation and do not contain file-path
  references that would have drifted.

## Phase 9 gate

Phase 9 is complete. `CHRONOSPARK.md` now accurately describes the v4.0.0
codebase produced by Phases 1–8.

**All nine rebuild phases are complete.**
