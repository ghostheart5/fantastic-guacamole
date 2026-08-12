# Testing implementation phases

This index records the approved testing-system sequence. A phase is complete
only for its declared scope; pending device, staging, human, and soak execution
does not become a passing result through documentation.

| Phase | Scope | Current status |
|---|---|---|
| 1 | CI/testing gate repair | Implemented; candidate evidence remains separate |
| 4 | Behavior-first unit and widget coverage | Implemented with runner-warning limitations |
| 5 | Accessibility and visual regression | Stopped pending approved production accessibility fix |
| 6 | Real application device and Patrol | Harness implemented; device execution pending |
| 7 | Maestro E2E | Harness implemented; device execution pending |
| 8 | Backend, staging, authorization, isolation | Local/static work completed; approved staging work pending |
| 9 | Advanced Human Root Testing | System defined; human cases not run |
| 10 | Property, model, fuzz, Monkey, chaos | Local harness implemented; device/staging work pending |
| 11 | Performance and soak | Local harness implemented; candidate/device measurements pending |
| 12 | Flaky-test control, regression governance, duplicate management | Governance assets and local checks implemented |
| 13 | Authoritative exact-commit and exact-binary release gate | Orchestrator and workflow dependencies implemented; no candidate finalized or released |

## Phase 12 operating sequence

1. Use changed-file selection only for PR-critical efficiency; it cannot replace
   a feature, nightly, or pre-release requirement.
2. Record flaky, skipped, conditional, quarantined, and duplicate-candidate
   evidence in the versioned registries.
3. Preserve first failures, expiry enforcement, ownership, and replacement
   coverage before any exception is considered.
4. Run the complete pre-release suite against the exact candidate. No changed-
   file selection or quarantine can silently waive a release veto.

## Phase 13 operating sequence

1. Existing runners produce ordered, immutable evidence for the 19 mandatory
   stages. The signed candidate is built once at stage 10 and hashed at stage 11.
2. The authoritative gate downloads that candidate and evidence from the named
   workflow run, checks every stage against the same commit and (from stage 11)
   binary hash, and refuses dirty-build, missing, skipped, expired, defective,
   unsigned, or chat-connected evidence.
3. A passing finalizer copies the exact candidate into a gated bundle, writes a
   non-overwritable manifest, and writes its SHA-256 sidecar.
4. Android release and web deployment locate a successful gate for their exact
   commit and flavor, verify the manifest/hash again, and consume the gated
   binary without rebuilding it.
