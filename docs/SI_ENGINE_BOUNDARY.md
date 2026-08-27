# SI Engine Boundary

## Public Surface

Code outside `lib/engine/si/` should import SI types through `lib/engine/si/api.dart` whenever a matching export exists.

The current public surface is intentionally limited to:

- orchestration entrypoints
- state and response models already consumed outside the engine
- selected offline derived engines already used by feature/state providers

The architecture guard in `test/architecture/si_public_boundary_test.dart` prevents new external imports from reaching deeper SI internals without an explicit boundary decision.

## Bounded Contexts

New SI classes should be placed into one of these buckets before being added:

- `core/`: shared pipeline modules and stable orchestration pieces
- `models/`: state, input, and response types
- `offline/`: deterministic derived engines used by UI/state providers
- top-level runtime facade: `SIEngineService`
- compatibility adapters: deprecated delegators that contain no orchestration logic

If a class does not clearly fit one of those buckets, it likely needs a new feature-focused subfolder instead of another top-level `si_*` file.

## Naming Guidance

Prefer behavior-first names over mythology-heavy names.

Preferred examples:

- `TaskRecommendationEngine`
- `NarrativeContinuityEngine`
- `EmotionTrendAnalyzer`
- `StateSnapshotProjector`

Avoid adding new names that only signal tone and not behavior, for example:

- `SiSyntheticParacosmGenerator`
- `SiSyntheticShadowModule`
- `SiCognitiveDreamspaceEngine`

Unreachable mythology-heavy scaffolding was removed after an import-graph audit and preserved by exact path and baseline commit in `docs/audits/si_unreachable_preservation_20260819.md`. New engine code must follow the behavior-first rule.

## Runtime Invariants

- One user request runs one `SICore` pipeline.
- One terminal validator decides whether the response can leave the facade.
- Memory records the validated response, never an unvalidated candidate.
- Provenance identifies the decision, model version, evidence, generation mode, validation result, and timestamp.
- Local SI state can be exported or cleared without deleting primary user data.
