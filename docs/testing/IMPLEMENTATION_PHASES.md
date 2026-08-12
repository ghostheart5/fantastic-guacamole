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

## Phase 12 operating sequence

1. Use changed-file selection only for PR-critical efficiency; it cannot replace
   a feature, nightly, or pre-release requirement.
2. Record flaky, skipped, conditional, quarantined, and duplicate-candidate
   evidence in the versioned registries.
3. Preserve first failures, expiry enforcement, ownership, and replacement
   coverage before any exception is considered.
4. Run the complete pre-release suite against the exact candidate. No changed-
   file selection or quarantine can silently waive a release veto.
