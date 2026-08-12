# Phase 4B — HLM-02 Typed History

## Original problem and decision

Phase 3 found incompatible history representations: Timeline events, completion events, logs, memories, and SI workspace data. `TimelineEventEntity` mixed user facts with Timeline-only projections, persisted a string event type, and used an untyped `relatedId`. HLM-02 establishes `HistoryEvent` as the typed durable contract for the existing Timeline persistence channel. It does not claim that logs, memories, progress calculations, or SI conversations are the same history stream.

`HistoryEvent`, `HistoryEventKind`, `HistoryEntityType`, and `HistoryEventSource` in `lib/domain/history/` are canonical. A fact includes an id, typed kind, UTC `occurredAt`, typed entity reference, provenance, structured payload, schema version, and explicit `legacyKind` where needed. Current state remains separate: task and goal records describe present state; `HistoryEvent` describes a recorded transition.

## Before and after

Before, `TimelineRepository` persisted `TimelineEventEntity` JSON in `timeline_events_v1`, and Timeline/Trajectory/SI consumed that read model through providers. After, the same key stores versioned `HistoryEvent` JSON. `TimelineHistoryAdapter` is the only compatibility boundary: existing Timeline producers continue to send `TimelineEventEntity`, the repository converts them to canonical history before persistence, and existing Timeline consumers receive their legacy read model reconstructed from history. This avoids edits to the protected dirty Timeline, task, goal, progression, trajectory, and SI providers.

The persistence authority for this HLM-02 channel is `TimelineRepository`; `getHistoryEvents` exposes its canonical read. No database migration is needed because decoding recognizes the old Timeline JSON shape and adapts it on read. The next write upgrades that item to the versioned canonical shape.

## Event, provenance, time, and linkage policies

Known Timeline types and known existing Creator titles map to typed kinds such as `taskCreated`, `taskCompleted`, `taskSkipped`, `taskRescheduled`, `goalCompleted`, and `milestoneReached`. Forecast, snapshot, risk, and recommendation values remain explicit `legacyTimeline` records rather than being presented as historical facts. Unknown legacy types retain their original text in `legacyKind` and raw source data in structured payload; they are never silently dropped.

`occurredAt` is serialized in UTC and reconstructed in UTC. Timeline display conversion uses local time, preserving its pre-existing display semantics. Entity linkage uses an explicit `HistoryEntityType` plus the existing stable `relatedId` as `entityId`; absent linkage remains absent. The current Timeline payload does not reliably carry producer provenance, so the adapter records `HistoryEventSource.unknown` rather than inventing a source.

## Producers, consumers, and duplicates

All existing Timeline producers—including Creator-mediated task/goal actions, Timeline actions, and legacy goal use cases—reach the canonical write adapter through `TimelineRepository`. Timeline UI, Trajectory, and SI continue to read their existing Timeline projections through the canonical-read adapter. No Progression scoring, Trajectory behavior, SI behavior, or Timeline UI was changed.

`TimelineEventEntity` is preserved as a deprecated compatibility read model, not removed. `CompletionEventEntity`, logs, memories, workspace/SI records, and feature-local history remain separate sources pending an explicit future consolidation decision; they were neither deleted nor reinterpreted by HLM-02.

## Branch and dirty-tree evidence

Phase 3 named `backup-before-flow-cleanup` and `rescue/chronospark-stabilization` as Timeline/history candidates. Their relevant Timeline implementation history leads to the existing repository/entity design; no prior typed-history model or migration was found, and no branch was merged.

`timeline_provider.dart`, `task_provider.dart`, `goals_provider.dart`, and DI providers were already dirty and were not touched. `timeline_event_entity.dart`, `timeline_repository.dart`, and the new history files were clean at the Phase 4B boundary. The HLM-01 protected `creator_provider.dart` hunks remain outside this change.

## Tests and unresolved debt

Focused tests cover construction, typed kinds, JSON round-trip, UTC timestamps, entity linkage, source, legacy decoding, unknown-kind preservation, repository round-trip, chronological ordering, and Timeline compatibility. The direct Flutter Tools path from HLM-01 is the validation runner.

Unresolved: separate completion/log/memory/SI stores remain non-canonical candidates; producer provenance is unknown for legacy Timeline records; explicit Creator/Smart Planner provenance and broader consumer migration require later scoped work.
