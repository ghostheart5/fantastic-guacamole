# Maestro Android validation

Use the maintained evidence runner to pair Maestro results with the selected
source, APK hash, installed package, device, JUnit results and runtime logs.
Maestro is installed separately from Flutter; `flutter pub get` does not install
it. A selected, booted disposable emulator is required for the QA journeys.

Many flows start with `clearState: true`. They reset local app data, and the runner
installs the selected APK. Do not run these suites on a personal installation.
Excluding the `destructive` tag excludes account deletion; it does not preserve
local app data or turn a directory run into a safe phone smoke test.

## Suites and evidence boundaries

| Suite | Selected work | Required target |
|---|---|---|
| `qa-smoke` | Five product flows, 04–08 | QA test installation; this remains the runner default |
| `qa-journeys` | Eleven flows including QA account controls, isolation, learning and restart readback | QA build on a disposable `emulator-<port>` target |
| `safe` | Numbered flows 01–11; excludes account deletion and the Priority 8 dependency flows | Disposable real accounts and compatible service/store state |
| `custom` | Explicit flow paths | Match the selected flows' account and data-reset requirements |
| `destructive` | Account deletion | Non-QA build, disposable real account and exact confirmation phrase |

`qa-journeys`, the maintained `.maestro/qa/` flows, and the Priority 8 flows are
rejected by the runner on physical devices or non-QA build profiles. Always pass
the intended emulator serial. Run one device automation process at a time.
`-SkipBuild` requires the retained APK path and its exact expected SHA-256; use
the QA artifact whose provenance matches this test run.

QA access does not verify real sign-in or Google Play account enrollment. The QA
profile deliberately bypasses authenticated onboarding. Verify fresh signup,
real authentication, onboarding, signed-artifact behavior and phone journeys
separately with their intended accounts and builds.

## Complete QA journey order

`run-all-tests.ps1` selects `qa-journeys`. Its eleven cases are:

| Order | Flow | Principal assertion |
|---|---|---|
| 1 | `flows/04-smart-planner.yaml` | Exact focused Planner input, typed-text readback and local response |
| 2 | `flows/05-creator.yaml` | Creator navigation and controls |
| 3 | `flows/06-si-console.yaml` | Local SI query and response |
| 4 | `flows/07-timeline.yaml` | Timeline navigation |
| 5 | `flows/08-progression.yaml` | Progression navigation |
| 6 | `qa/09-settings.yaml` | Required tester account controls, with enabled assertions |
| 7 | `qa/10-subscription-containment.yaml` | Hidden commerce surfaces under the current containment policy |
| 8 | `qa/11-logout.yaml` | Tester exit returns to the login boundary and removes navigation access |
| 9 | `flows/priority8-account-isolation.yaml` | A → B → A sentinel preservation and isolation |
| 10 | `flows/priority8-learned-lifecycle.yaml` | Planner → Creator confirmation → scheduled task → completion → learning UI |
| 11 | `flows/priority8-learned-lifecycle-readback.yaml` | Immediate process restart and preserved learning-ledger readback |

The runner writes a runtime configuration with `executionOrder.flowsOrder` and
`continueOnFailure: false`, passes it through `--config`, and records its path,
hash and sequence in the evidence. An ordered CLI argument list alone does not
guarantee Maestro execution order. See the official [sequential execution
contract](https://docs.maestro.dev/maestro-flows/workspace-management/sequential-execution).

The readback must follow the lifecycle without another clear-state flow, data
reset, identity change or unrelated test in between. It stops and relaunches the
app while preserving data. For a separate diagnostic run, preserve the same test
installation and explicitly run lifecycle, then readback. Running the flow
directory alphabetically is unsuitable for this dependent pair.

The visible learning ledger has a generic `Task Lifecycle … completed … helped`
row. It proves that a completed outcome is readable after restart; it cannot
identify which task produced that outcome. The separate
[`planner_learning_identity_test.dart`](../integration_test/planner_learning_identity_test.dart)
regression checks the actual Planner-created task and its outcome by `subjectId`
after storage reopening, independently of the earlier seed task. Keep both proofs.

## Running the maintained evidence path

```powershell
# Preflight checks tools, source, target, flow contracts and output location.
# It does not build, install or launch an app.
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/run_maestro_android_evidence.ps1 `
  -Suite qa-journeys -BuildProfile qa -DeviceSerial emulator-5554 -PreflightOnly

# Build the QA test APK and run all eleven cases with a bounded 40-minute limit.
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/run_maestro_android_evidence.ps1 `
  -Suite qa-journeys -BuildProfile qa -DeviceSerial emulator-5554 -ExecutionTimeoutSeconds 2400

# Short five-flow QA smoke suite.
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/run_maestro_android_evidence.ps1 `
  -Suite qa-smoke -BuildProfile qa -DeviceSerial emulator-5554
```

The QA build targets x86_64 to avoid compiling unused ARM artifacts for local
automation. The default source gate requires a clean checkout. An intentional
diagnostic `-AllowDirtyTree` run records the commit and dirty count; preserve its
source diff separately because a dirty count is not an immutable source identity.
A detached HEAD is valid and is recorded with an empty branch name.

Evidence is stored under `artifacts/maestro/`. A complete pass requires zero
Maestro errors/timeouts, valid JUnit with exactly one passing testcase per selected
flow and zero skipped cases, and a complete Logcat capture. The runtime scan also
requires zero configured framework, fatal or ANR markers. UI assertions passing
while Flutter logs an error is a failed run. Missing or interrupted logging is
also a failure; do not weaken the scanner or relabel incomplete runs as passes.

Known credentials, emails, bearer tokens, JWTs and credential-shaped fields are
sanitized from Logcat. Raw Logcat is removed unless `-KeepRawLogcat` is explicitly
requested. Native stderr remains in diagnostic logs but is excluded from parsed
device stdout, preventing PowerShell progress XML from corrupting device metadata.

The hosted `.github/workflows/maestro-runtime.yml` still selects the five-flow
`qa-smoke` profile on its pinned API 35 emulator. A hosted smoke pass does not mean
the eleven-flow local journey suite or real-account/store journeys executed.

## Commerce and account operations

The current QA journey verifies subscription containment: Settings omits the
plan-and-credits card. It does not verify purchase, restore, billing frequency,
entitlements or simulated purchasing. `flows/10-subscription.yaml` exercises a
different, commerce-enabled product contract and must not be substituted for the
containment flow or reported as passing while commerce remains disabled.

Real-account flows use `MAESTRO_TEST_EMAIL`/`MAESTRO_TEST_PASSWORD`; signup uses
`MAESTRO_SIGNUP_EMAIL`/`MAESTRO_SIGNUP_PASSWORD`. Supply disposable test credentials
privately. The `safe` suite includes these flows and requires compatible service
state; its name does not promise a contained current build can pass every flow.

Account deletion is rejected from normal/custom suites. The dedicated command
requires a disposable account and explicit destructive intent:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/run_maestro_android_evidence.ps1 `
  -Suite destructive -BuildProfile debug -DeviceSerial emulator-5554 `
  -DestructiveConfirmation 'DELETE DISPOSABLE ACCOUNT'
```

## Editing and static validation

Shared helpers live in `subflows/`; dedicated QA account/containment flows live in
`qa/`. Preserve the QA-only login helper's refusal to use real credentials.
Required assertions must execute; conditional branches must not allow every
account-control assertion to disappear when a selector changes.

Target the observed semantics. `HoloButton` exposes its original casing despite
uppercase display text. Account action tiles join title and subtitle with a
period; Settings category headers use a newline. Planner entry must target the
editable hint, confirm focus, and read back typed text before requesting guidance.

`dart run tool/validate_maestro_flows.dart` checks YAML structure, app IDs, command
lists and referenced subflows. It does not execute selectors or validate runtime
ordering. Runtime evidence and the separate runner fixture tests remain required.
