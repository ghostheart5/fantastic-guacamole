# Phase 4F.3 — HLM-06 Preference Producer Isolation

## Provenance

| File | Phase 2 identity | Result |
| --- | --- | --- |
| `settings_screen.dart` | current SHA-256 equals snapshot | SNAPSHOT-VERIFIED |
| `domain_usecase_providers.dart` | current SHA-256 equals snapshot | SNAPSHOT-VERIFIED |
| `profile_controller.dart` | differs from Phase 2 | expected HLM-05 progression commit plus protected Profile work; sound must be isolated from progression/session regions |

Theme provider/repository and `app_providers.dart` are currently clean; no Phase 2 copy was required for their planned direct edits.

## Producer inventory

`settings_screen.dart` writes the sound toggle directly to `soundEnabledProvider`; its UI file has snapshot-verified responsive/navigation/tutorial changes (SETTINGS-UI-H01, unrelated) surrounding the sound control. The sound callback itself is a shared HLM-06 boundary and requires deterministic index construction if migrated.

`domain_usecase_providers.dart` is snapshot-verified. Its theme-use-case exposure (`saveThemeUseCaseProvider`, around line 647) is the smallest future canonical-action exposure. Other dirty hunks are task/goal/SI/lifecycle unrelated and excluded (DOMAIN-UC-H01+).

Profile sound exists in `ProfileState.soundEnabled`, JSON, hydration, and `toggleSound`; these are PROFILE-COMPATIBILITY. They must not disturb HLM-05 progression or protected session hunk regions.

## Ownership traces

- Sound writes: Settings UI → `soundEnabledProvider`; Profile also persists `soundEnabled`; runtime consumers include settings initialization, level-up overlay, Creator, Timeline, notifications, and task flows. Target: canonical settings action/state → runtime sound adapter; Profile remains compatibility projection.
- Theme writes: Settings/theme UI → `ThemeActions` → theme use cases/repository; `SettingsEntity.themeMode` duplicates this truth. Target: canonical settings action/state → theme adapter/repository.
- Onboarding: app/bootstrap/auth-session lifecycle keys and providers own workflow completion/version/step. It remains WORKFLOW-STATE; no HLM-06 migration.
- Reminders and feature keys are feature state or adapters later; no minimum HLM-06 producer migration beyond global sound/theme.

## Minimum migration and patch strategy

1. Extend clean `SettingsEntity` and define typed read/update actions above `ISettingsRepository`.
2. Add a clean canonical settings state/action adapter using the existing repository provider.
3. Migrate sound runtime adapter and theme adapter.
4. Isolate settings-screen sound producer and domain-use-case exposure with deterministic HEAD-plus-HLM blobs.
5. Preserve Profile sound as compatibility only; do not change onboarding or reminder ownership.

| File | Overlap | Strategy |
| --- | --- | --- |
| SettingsEntity / typed actions / new state adapter | NONE | direct clean edit |
| settings screen sound callback | PARTIAL | deterministic index blob |
| domain use-case providers theme/settings exposure | PARTIAL | deterministic index blob |
| Profile sound compatibility | DIRECT shared protected boundary | deterministic index blob or adapter without touching Profile |
| theme provider/repository | NONE | direct clean edit/adaptation |
| onboarding | excluded | no change |

No preservation baseline is needed if each candidate is staged deterministically. User-scope risk remains: all saves must continue through SettingsRepository and its protected user-scoped dispatcher; no global sound/theme cache may become persistence authority.

## Focused test matrix

Canonical sound write/read and runtime propagation; Profile compatibility; canonical theme write/read and theme propagation; legacy migration precedence and restart; settings UI dispatch; no raw canonical persistence; account A/B isolation and switching; onboarding non-migration; and no HLM-01–05 domain state in settings.

## Status

This is planning only. HLM-06 is **SAFE WITH CONDITIONS**: implementation requires deterministic isolation for the two snapshot-verified producer seams and must keep Profile sound as a compatibility adapter.
