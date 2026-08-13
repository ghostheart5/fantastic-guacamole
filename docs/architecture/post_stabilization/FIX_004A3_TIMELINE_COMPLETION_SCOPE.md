# FIX-004A3 Timeline / Completion account scope

## Candidate scope

FIX-004A3 scopes Timeline and Completion Event persistence to the active
`AccountStorageScope` V2 namespace. The candidate changes only:

- `TimelineRepository` and `CompletionEventRepository` V2 storage keys;
- their repository providers, which watch `accountStorageScopeProvider`;
- lifecycle invalidation for Timeline, Completion, and the cached Timeline
  view use case.

Legacy `timeline_events_v1` and `completion_events_v1` remain inactive and are
never claimed, overwritten, or used as a fallback.

## Transition boundary

The proven Timeline read chain is:

`timelineProvider` → `viewTimelineUsecaseProvider` →
`timelineRepositoryProvider`.

On identity transition the lifecycle invalidates, in order within its existing
invalidation phase:

1. `timelineRepositoryProvider`
2. `viewTimelineUsecaseProvider`
3. existing Timeline read models, including `timelineProvider`
4. `completionEventRepositoryProvider`
5. existing Completion read context

This is an invalidation-only change; suspend, drain, ownership, hydration,
ready, and resume ordering are unchanged.

## Final certification status

Starting HEAD: `d839b1c5364fab671ef5a3220b432e9cc18ad2c0`. PRE-TEST-02A,
02B, 02C, 02D, E1, and E2 are PASS. The exact-index candidate was constructed
from that HEAD plus only the four authorized production files, four A3 tests,
and two A3 documents. It passed 76 focused tests and targeted analysis with
zero diagnostics and zero dirty-source dependencies.

The final command harness proves complete, delay, and skip use the real
Timeline action, notifier, use case, and `TimelineRepository` to write the
active A/B V2 authority. It proves A-to-B isolation, return-to-A restoration,
B-owned writes, and byte-for-byte V1 preservation. Optional CompletionEvent
tracking remains not exercised because its existing feature flag is disabled;
the candidate adds no fan-out.

The candidate remains uncommitted for the final commit operation. This
document intentionally records no commit hash.
