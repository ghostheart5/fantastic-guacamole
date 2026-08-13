# HLM-06 canonical settings preference boundary

`SettingsEntity` is the authoritative, scoped record for sound and theme.
`soundEnabled`/`soundEstablished` and `themeMode`/`themeEstablished` are
persisted exclusively by `SettingsRepository` through
`SettingsPreferenceController`.

On first hydration only, an unestablished sound value may adopt the scoped
legacy Profile value and an unestablished theme may adopt a valid device-global
legacy `app_theme_entity_v1` value. The controller immediately persists the
corresponding establishment marker. Once established, legacy data is never
read as an overwrite source.

Profile sound is a read-only compatibility projection. `ProfileActions` routes
sound changes to the canonical controller, while runtime sound receives the
same projection. Theme actions similarly route through the controller;
`ThemeRepository` is retained only as a legacy migration reader and optional
runtime compatibility source. `PreferenceService` continues to own unrelated
workflow keys and does not write sound or theme.

Onboarding remains workflow state. This migration neither changes onboarding
routing nor reinterprets onboarding fields as preferences.
