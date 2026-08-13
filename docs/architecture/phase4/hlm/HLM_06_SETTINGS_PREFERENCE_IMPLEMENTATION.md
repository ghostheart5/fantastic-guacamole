# HLM-06 — Canonical settings and preference authority

## Reconciliation

Starting authoritative HEAD: `b42b5125c0ac7e429db77cab13cc7c646887ab13`.

The preserved HLM-06 candidate contained 12 entries. Ten applied unchanged.
Two were deterministically rebuilt from current HEAD:

| Path | Rebase result |
| --- | --- |
| `lib/data/repositories/settings_repository.dart` | Kept Root-05 cancellation, drain, write queue, and sync dispatch. Added only `soundEstablished` and `themeEstablished` decode/encode fields. |
| `lib/state/controllers/profile_controller.dart` | Kept Root-03 scoped migration, HLM-05 progression, and Root-05 write drain. `toggleSound` now updates only legacy in-memory compatibility state and does not persist. |

No candidate was obsolete. The remaining entries preserve the SettingsEntity
marker seam, SettingsPreferenceController, Profile/Theme action routing,
legacy Theme read seam, settings UI projection, compatibility projection, and
focused tests.

## Authority

`SettingsEntity` plus `SettingsPreferenceController` own canonical sound and
theme state. `SettingsRepository` is the sole active persistence path for the
canonical record `settings_entity_v1`.

- Sound active canonical writer count: **1** (`SettingsPreferenceController`
  through `SettingsRepository`).
- Theme active canonical writer count: **1** (`SettingsPreferenceController`
  through `SettingsRepository`).
- `ProfileController.toggleSound` is compatibility-only and no longer saves.
- `ProfileActions` and `ThemeActions` forward changes to the canonical
  controller.
- `ThemeRepository.getStoredTheme` is a legacy migration reader. Its retained
  interface write method has no production caller; Theme actions no longer
  invoke the legacy theme use cases.
- `PreferenceService` does not write sound or theme.

## Migration and scope

Missing markers decode as `false`. An unestablished canonical preference reads
its legacy source once, immediately saves the canonical value plus marker, and
never reimports after establishment. Existing markers therefore win over later
legacy changes. Legacy Profile sound lookup uses the authenticated, normalized
scope. Account isolation and repository invalidation are supplied by the
committed lifecycle coordinator and stable session boundary; no second settings
scope/provider was introduced.

Onboarding remains workflow state. HLM-06 neither moves it into the preference
controller nor changes its routing.

## Validation

- HLM marker/migration/propagation tests: 6 passing cases.
- HLM-05 progression, Root-03 migration, Root-05 settings/learning drain, and
  lifecycle/identity/Insights regressions: 22 further passing cases.
- Targeted analysis: 0 diagnostics across all HLM-06 production paths and
  focused tests.
- Exact-index validation re-runs the same candidate-only set after staging.

The protected 12-entry manifest is retained as the source-presence record;
this document records the final current-HEAD reconciliation rather than adding
new production authority.
