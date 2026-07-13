# SoulMap FlowMap

## Trigger
SoulMap profile changes, or upstream behavioral signals (tasks/goals/memories/timeline/milestones) change.

## Diagram
```mermaid
flowchart TD
   A[Profile or Signal Change] --> B[SoulMap Profile Store]
   B --> C[SoulMap Alignment Provider]
   C --> D[Load Multi-signal Context]
   D --> E[Compute Dimension Scores]
   E --> F[Derive Overall Strongest Weakest]
   F --> G[Build Summary and Future-self Comparison]
   G --> H[Render SoulMap UI]
   H --> I[Feed SI Pipeline Aggregation]
```

## Flow
1. User updates SoulMap profile fields or system data changes in upstream providers.
2. SoulMap profile store loads/saves authored profile state.
3. SoulMap alignment provider gathers multi-signal context:
   - trajectory summary
   - goals
   - memories
   - tasks
   - timeline health/risk
   - milestone summary
   - core values alignment
   - synthetic soul state
4. Dimension scores are computed (purpose, identity, future self, vision, etc.).
5. Overall alignment, strongest area, and weakest area are derived.
6. Summary and future-self comparison providers generate final user-facing outputs.
7. UI surfaces render alignment, recommendations, and future-self gap.
8. SI pipeline consumes SoulMap alignment as part of system intelligence aggregation.

## Data and Services
- Screen: soul map surfaces and SI summaries
- Provider/Controller: soul map profile/alignment/summary/future-self comparison providers
- Use case: provider-level computation pipeline (composed signal scoring)
- Repository: SoulMap profile store wrapper over shared preferences
- Data sources: shared preferences + upstream provider state
- Services: synthetic soul layer, SI pipeline aggregation

## Errors
- Profile serialization/deserialization failure
- Upstream dependency provider failure

## Fallback
- Default to empty profile and baseline alignment
- Continue with partial context when one upstream source fails
- Preserve stable summary output with deterministic defaults

## Analytics Event
- soulmap_profile_updated
- soulmap_alignment_rendered
- soulmap_gap_reviewed

## Audit Checklist
- ../CORE_VALUES_SOULMAP_AUDIT.md
