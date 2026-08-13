# Phase 4F.1 — Settings Provenance Recovery

## Recovery result

The Phase 2 recovery directory was readable through approved read-only access. Snapshot copies and `snapshot-root/manifest.json` were located for both protected settings-seam files.

| File | HEAD blob | Current SHA-256 | Phase 2 SHA-256 | Result |
| --- | --- | --- | --- | --- |
| `lib/data/repositories/settings_repository.dart` | `3815dffe11e384302dd1e25ba58bf1c607143298` | `B8520F5F4BA71F6CC5B2C773BF134AE1A7B4D95DB0082712B312D9D87071DE4A` | `B8520F5F4BA71F6CC5B2C773BF134AE1A7B4D95DB0082712B312D9D87071DE4A` | SNAPSHOT-VERIFIED |
| `lib/data/di/repositories_providers.dart` | `6383804724f7465be75bf58b6358b745aa67ca8e` | `E680DFEBD4EB379278702E5977F20FA72377053B65407A0481F1C482F25491C6` | `E680DFEBD4EB379278702E5977F20FA72377053B65407A0481F1C482F25491C6` | SNAPSHOT-VERIFIED |

The direct snapshot bytes equal the current bytes for both files. There is no evidence of post-Phase-2 mutation.

## Attribution and decision

The protected repository hunks are historically attributable as the Phase 2 preserved cancellation/write-serialization and save/sync behavior. The DI hunks are historically attributable as lifecycle/dispatcher watching and authenticated-user dispatch behavior. This establishes preservation provenance, but does not authorize broad inclusion of adjacent non-settings lifecycle hunks.

A settings-seam preservation baseline is therefore **NEEDS USER DECISION** rather than automatically justified: the repository hunks are coherent, while `repositories_providers.dart` also includes task/goal/habit lifecycle hunks that are outside HLM-06. Any future baseline must explicitly isolate its included DI hunks and show whether the dispatcher change requires those adjacent lifecycle changes.

## Alternative path

**Adapt above baseline: YES WITH CONDITIONS.** HLM-06 can leave the protected repository internals, write queue, cancellation, provider lifecycle, and user-scoped dispatcher unchanged; it may establish canonical preference semantics above `SettingsRepository` and use the repository as its persistence implementation. It must still use deterministic hunk isolation for any necessary SettingsRepository/DI integration and preserve the verified protected behavior.

## Remaining risk

Snapshot provenance is now resolved, but semantic dependency between settings provider lifecycle and the adjacent task/goal/habit lifecycle hunks remains untested. No production change or preservation commit is made in this phase.
