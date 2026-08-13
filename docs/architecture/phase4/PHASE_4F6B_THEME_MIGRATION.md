# Phase 4F.6B — Legacy Theme Migration Isolation

## Current path and schema

`ThemeActions.save/switchTo` uses theme use cases and `ThemeRepository`. The repository persists `AppThemeEntity` JSON under `app_theme_entity_v1`: `id`, `name`, and `isDark`; supported stored themes are dark/light, missing or malformed values return `AppThemeEntity.defaultTheme()` (dark). `CurrentThemeController` hydrates this repository and application consumers read `currentThemeProvider`.

The HLM-06 canonical representation is `SettingsEntity.themeMode` (`dark`, `light`, or `system`) persisted as `themeMode` within `settings_entity_v1` through `SettingsRepository`. The field already exists in committed code, defaults to `system`, and has no migration marker. Therefore equality with a default is not a valid explicitness signal.

## Decision

Use an additive `themeEstablished` migration marker in canonical settings (or equivalent versioned explicitness state). It is the smallest backward-compatible mechanism: old settings records decode with `themeEstablished: false`; a user selecting even the default marks it true.

Precedence:

1. If canonical theme is established, use it and never import legacy again.
2. Otherwise, if `app_theme_entity_v1` decodes, map dark/light to canonical mode, persist canonical settings plus marker, and use it.
3. Otherwise establish and persist the safe canonical default plus marker.

Repeated hydration is idempotent. Legacy data is not deleted. After migration, ThemeRepository may be a one-way runtime/legacy compatibility mirror only; it must never override canonical Settings.

## Scope and startup

ThemeRepository currently uses an unscoped shared-preferences store; SettingsRepository dispatches through protected authenticated-user scoping. This is a material scope condition: migration may adopt the device-global legacy theme into the first unestablished canonical scope, but account switching must subsequently hydrate that account’s canonical value and must not re-import stale device theme. Safe sequence: resolve settings scope, hydrate canonical Settings, migrate only if unestablished, then update the runtime theme adapter. This prevents legacy startup hydration from overwriting a canonical value.

## File and hunk strategy

| File | Status | Strategy |
| --- | --- | --- |
| `settings_entity.dart` | clean | CLEAN EDIT for marker/copy/validation |
| `settings_preference_provider.dart` | untracked HLM-06 work | clean HLM edit for typed migration adapter |
| `theme_repository.dart` | clean | ADAPTER ONLY; retain legacy decode/read |
| `theme_provider.dart` | clean | HUNK-LEVEL/clean adapter update |
| `settings_screen.dart` | protected dirty (`SETTINGS-UI-H01`) | deterministic HEAD+HLM blob for theme producer only |
| `domain_usecase_providers.dart` | protected dirty (`DOMAIN-UC` unrelated hunks) | no change unless minimal exposure is proven |

No dirty theme provider/repository hunks were found. The settings UI’s responsive/navigation/tutorial hunk is protected-unrelated.

## Adapter and final write direction

The typed `ThemeMigrationAdapter` belongs beside `SettingsPreferenceController`; it reads the legacy ThemeRepository, maps `AppThemeEntity` to a validated canonical mode, checks canonical explicitness, and invokes the typed settings save. It is theme-specific, not a generic migration framework.

Final direction: Settings UI/theme action → SettingsPreferenceController → SettingsEntity → SettingsRepository → runtime theme adapter → app consumer. Any ThemeRepository write is optional one-way compatibility mirroring.

## Tests and status

Tests: legacy decode/map; unestablished migration; persistence/marker; repeat hydration; explicit default; canonical precedence; malformed/missing legacy; runtime propagation; user/device and account-switch behavior; one-way compatibility; UI canonical dispatch; startup ordering.

Theme migration is **SAFE WITH CONDITIONS**: migration marker and device-global-to-user-scoped account semantics must be implemented and exact-index isolation is required for the Settings UI producer.
