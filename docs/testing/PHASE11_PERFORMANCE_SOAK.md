# Phase 11 performance and soak testing

Version: 1.0.0
Status: defined local harness; device and soak measurements pending

## Safety boundary

Phase 11 adds test-only measurement contracts, a profile definition, and a
local-safe runner. It makes no production performance change, does not contact
any backend, and does not modify or connect Smart Planner, SI Console, or chat
features. A proposed threshold is not a validated baseline and must not be
treated as release evidence.

## Current inventory and limitations

Existing UI frame-budget files time in-process widget pumps and accept an empty
frame-timing stream. They do not identify a candidate binary, hardware, OS,
build mode, data scale, warm-up policy, percentile, or regression. The static
performance contract checks source text only. The historical optimization
report contains estimates and guidance, not repeatable candidate measurements.

## Measurement record contract

Every non-local result records commit SHA, binary SHA-256, device, OS, build
mode, dataset, method, warm-up policy, sample count, median, p95, allowed
threshold, and median regression percentage. Store approved baselines apart
from failure diagnostics. A missing field, an unverified binary hash, or an
unidentified environment makes the result pending rather than passing.

The local harness uses deterministic collection work only. It validates
measurement mechanics; it is not a startup, frame, memory, network, database,
or application-user-journey result.

## Datasets

| Dataset | Definition |
|---|---|
| Empty | 0 user-created records |
| Small | 25 tasks and 50 Timeline events |
| Realistic | 250 tasks and 2,000 Timeline events |
| Heavy | 2,000 tasks and 20,000 Timeline events |
| Extreme | 10,000 tasks and 100,000 Timeline events |

## Provisional budgets -- not validated

The machine-readable profile lists the candidate metrics and initial p95
targets: cold/warm startup, Nexus first render, Creator save, Timeline
load/search/large-list scrolling, Trajectory calculation, Progression
recalculation, synchronization backlog drain, database migration, background
recovery, notification scheduling, Smart Planner timeout, and SI Console
timeout. It also sets provisional memory-growth (20 percent) and janky-frame
(2 percent) ceilings.

These are planning thresholds only. Release Engineering may replace them only
after a comparable signed nonproduction baseline has samples from the required
physical-device matrix and a human reviewer approves the change.

## Tiers and execution

| Tier | Scope | Status |
|---|---|---|
| PR | Local deterministic measurement-contract and pure-workload checks | Available; not a device result |
| Nightly | Isolated emulator feature measurements | Pending device/candidate |
| Physical-device release | Signed nonproduction candidate, all listed metrics, data scales, frame and memory capture | Pending candidate/device |
| Soak | Several-hour isolated candidate campaign | Pending candidate/device |

Run local profile validation only:

~~~powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tool\performance\run_phase11_local_measurements.ps1 -Tier pr
~~~

The runner refuses to launch device work. Device and soak commands require a
separate approved candidate command and may never target production.

## Soak scenarios and evidence

The soak campaign repeats creation/completion, top-level navigation,
background/foreground, synchronization, long Timeline scrolling, notification
processing, and offline-queue accumulation/recovery. The release campaign also
runs a several-hour stability scenario. Capture process exit, crash, ANR,
memory trend, dropped frame count, queue size, notification result, final
state, and the full measurement record contract. A crash, ANR, uncontrolled
memory growth, lost queued mutation, or unknown final state is a release-blocking
failure, never a skipped pass.

## Pending measurements

No Phase 11 device, candidate, database, network, or soak measurement has
been executed. All such measurements are pending; no performance claim is made.
