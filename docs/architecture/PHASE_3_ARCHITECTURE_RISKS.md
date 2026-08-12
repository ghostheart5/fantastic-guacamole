# Phase 3 Architecture Risks

| ID | Rank | Finding and evidence |
| --- | --- | --- |
| R-01 | P1 | Notes, habits/routines, and task kinds describe overlapping life records without a single lifecycle/persistence owner. |
| R-02 | P1 | History is split across Timeline, logs, memory, completion events, and SI workspace payloads. |
| R-03 | P1 | Intervention acceptance/dismissal has controller feedback calls but no durable, queryable intervention contract. |
| R-04 | P2 | Progress calculations are distributed among progression, streak, session, learning, and provider-derived metrics. |
| R-05 | P2 | Smart Planner inputs and SI context are assembled from provider graphs rather than a canonical Human Life Model read boundary. |
| R-06 | P2 | Preferences are persisted and read through multiple feature/local-store paths. |
| R-07 | P3 | `TaskEntity`/`Task`, priority forms, and Timeline facts/projections add maintainability ambiguity. |

No P0 finding was established: the audit found serious truth ambiguity, but no evidence of irreversible data corruption in the committed baseline.
