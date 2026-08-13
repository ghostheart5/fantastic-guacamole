# Phase 4F.6A — Profile Sound Authority Isolation

## Current writers

There are two persisted sound authorities today: canonical-intended `SettingsEntity.soundEnabled` through `SettingsRepository`, and legacy `ProfileController.toggleSound`, reached by `ProfileActions.toggleSound`. The latter calls the Profile controller and persists `ProfileState.soundEnabled`; it is the remaining competing writer.

## Readers and compatibility

`ProfileState.soundEnabled` is projected by `ProfileService` into `ProfileModel`, then `ProfileViewState`, consumed by `features/profile/ui/profile_screen.dart`. Creator/runtime sound consumers currently read `soundEnabledProvider`, not Profile directly. Profile is therefore a legacy UI compatibility reader, not a required runtime authority.

## Hunk map

| Region | Classification | Future handling |
| --- | --- | --- |
| Profile sound field, `copyWith`, JSON, hydration | PROFILE-COMPATIBILITY | retain as legacy mirror until all readers migrate |
| `ProfileController.toggleSound` | HLM06-REPLACEABLE / DIRECT | stop independent persistence or redirect through canonical Settings |
| `ProfileActions.toggleSound` | HLM06-ADAPTABLE / NONE | redirect to `SettingsPreferenceController` |
| Profile service projection | PROFILE-COMPATIBILITY | project canonical sound or retain mirror during transition |
| Profile progression/session/auth methods | PROTECTED-UNRELATED | excluded |

## One-way contract

`SettingsEntity.soundEnabled` is canonical and `SettingsPreferenceController` is the only migrated write authority. The smallest behavior-preserving option is A: `ProfileActions.toggleSound` forwards to Settings; Profile consumers read a canonical projection through `ProfileService`/provider adaptation. Profile’s stored sound field remains legacy data and must not write back to Settings after canonical migration.

Legacy migration requires explicit canonical-value detection. The existing v1 record cannot distinguish absent `soundEnabled` from defaulted `true`, so the canonical settings record needs an additive migration marker/versioned nullable decode before Profile sound is adopted once. Rule: explicit canonical wins; otherwise adopt legacy Profile sound once, save settings plus marker, then canonical wins on every subsequent hydration.

## Required future edits and staging

| File | Overlap | Strategy |
| --- | --- | --- |
| `settings_preference_provider.dart` | NONE | clean edit for migration marker/typed action |
| `settings_entity.dart` / repository decode | NONE / protected repository read region | additive clean entity change; repository hunk isolation only if needed |
| `profile_provider.dart` | NONE | direct edit to redirect action |
| `profile_controller.dart` | DIRECT | external HEAD-plus-HLM deterministic blob, sound-only diff |
| `profile_service.dart` | NONE | adapter projection if required |

Focused tests: one-time legacy migration; canonical precedence; no Profile independent persistence; compatibility readers; Settings→Profile projection; restart; user scopes; no sync loop.

## Status

No sound migration is implemented in this phase. The sound patch is **SAFE WITH CONDITIONS**: canonical explicitness must be added before legacy adoption, and Profile staging must exclude all HLM-05/session/auth hunks.
