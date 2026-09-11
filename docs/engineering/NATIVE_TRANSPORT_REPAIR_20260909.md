# Native validation transport repair

App source remains `4d8a916e26dd9e025d7583e9b83dc2d92b7b71c2` and signed
candidate remains build run `34421127362`, version `4.1.0+2026083022`.
This repair changes validation infrastructure only; it does not rebuild the app.

## Failure and repair

Runs 34421999910 and 34423493808 each lost ADB connectivity during Flutter DDS
startup in different invocations. Both failed before the interrupted application
cases loaded. All five file/viewport combinations passed individually across
those runs, but neither complete native workflow passed. Raw failures remain.

Previously, five fresh guests reused emulator port 5554 and an implicitly started
ADB server. The runner did not own that server's process or verify its continuity.
The specific cause of the old interruptions is not conclusively established.

Each integration invocation now starts a foreground ADB server on its own
non-default loopback port (55001 through 55005), using the guest's prepared host
identity. The emulator and Flutter clients inherit that same server connection.
Emulator console ports 5586 through 5594 are outside ADB's default discovery
range, reducing interference from another/default server. The server disables
wireless auto-connect and restricts USB selection to a nonexistent test serial.
It never kills or adopts a pre-existing server or touches the default server.

Health checks match the requested serial to the owned emulator process's launch
port and AVD. The foreground server must survive the entire invocation. Its
transport/socket/service diagnostics are retained. Only its owned process is
terminated; a surviving listener, unexpected exit or unproved server cleanup
fails the gate and prevents the next guest from starting.

All five invocations, 15 test executions, API 36, viewports, fakes, test sources,
timeouts, runtime error scans and full-capture requirements are unchanged. There
are no within-case retries or state resets. The strict 16 KB lane is unchanged.

## Verification before hosted execution

- 35 existing final-validation contract tests passed, including rejection of
  missing test counts, incomplete capture, wrong devices and failed cleanup.
- Six new ADB ownership tests passed: invalid/default ports, busy-port refusal,
  environment restoration, unexpected exit, launch failure and owned cleanup.
- The same ADB helper booted the local existing API 36 emulator on isolated
  server 5048 / emulator 5586. Settings rendered and 12 shell health samples
  passed over approximately one minute; both owned processes stopped afterward.
- Initial Windows helper startup rejected a named-host listen socket. The
  retained diagnostic identified this backend restriction; `-L tcp:PORT`
  without `-a` supplies the supported loopback-only listener.

Local AVD repair preserved userdata and snapshots, backed up config.ini, selected
cold boot, two cores, explicit 2560 MB RAM and software graphics. Local health
is not a substitute for full native tests or exact Play-signed upgrade evidence.
The final hosted result must be read separately before claiming native acceptance.

## Follow-up: first compile and guest transport interruption

Run 34426553189 passed 14/15 executions with owned-server continuity and cleanup.
Startup compiled for 693.9 seconds with its guest already booted, then lost its
transport during VM-service startup. Its log collector exited 255 and the
unchanged 900-second canonical timeout expired with zero cases executed.
The server log establishes a remote read failure while the owned server stayed
alive. It does not establish server replacement or prove a specific guest cause.

The next revision compiles the maintained startup target before any guest boots,
separating the heavy initial native dependency build from emulator execution.
This preparation starts no emulator and executes no test, records an APK digest,
and must succeed before the native suite starts. The canonical five invocations
still build and run normally, with their original 900-second limits and all
capture/assertion gates. Emulator kernel output is also retained for diagnosis.
This is a resource-contention mitigation to validate, not proof of root cause.

References: [ADB options and diagnostics](https://android.googlesource.com/platform/packages/modules/adb/+/HEAD/docs/user/adb.1.md),
[ADB server environment routing](https://android.googlesource.com/platform/packages/modules/adb/+/refs/heads/main/client/commandline.cpp).

## Follow-up: pinned API 36 host runtime

Run 34428738896 compiled before boot and again passed 14/15 executions. The
Planner invocation failed before its test started: guest adbd recorded a write
failure, the host recorded a remote read failure, and DDS startup failed. The
owned server remained alive; retained kernel output contains no kernel panic.
The initial compile mitigation did not resolve the intermittent transport loss.

The API 36 lane now uses Google's archived Emulator 36.6.11 build 15507667,
verified against its published SHA-256 before extraction and its version after
extraction. It is installed in a new runner-temp directory; the SDK emulator and
strict 16 KB lane remain unchanged. This isolates the host-runtime version from
37.1.11, used by the failed runs. It does not assert an upstream regression has
been proven. The same version passed the local Windows emulator OS/touch check;
that does not itself establish Linux integration success. All 15 canonical
executions, fatal/log continuity gates and timeouts remain required.

Published archive: https://developer.android.com/studio/emulator_archive
Linux SHA-256: 1eade4cf2df6ea8eeead4902c635897ba12aaa32aac4389eaae0fdb498a5b830

## September 10 follow-up for candidate 3025

Current app source is `a8a625c55ef5f280504da5fc5a78695e45585e4c`, candidate
build run `34535515386`, AAB SHA-256
`199e37faa0240d82acce75cfa20fbc65dce8b41ebe918d568c2b8c9a69e41f7f`.
The earlier source and candidate above remain historical evidence.

The native lane uses API 36 Google APIs revision 7, a checksum-pinned ADB
36.0.2 foreground server and the default Flutter DDS transport. The no-DDS
workaround was removed because Flutter's native integration golden listener
uses DDS even when the individual test does not compare a golden image.

Run 34544342882 completed nine small-screen tests and five tall-screen tests,
then lost the tall guest's ADB connection. Run 34546671574 completed fourteen
tests, but startup lost its connection while attaching VM services. Owned ADB
processes stayed alive and all five guests, collectors and servers were cleaned
up. No captured application fatal or kernel panic establishes an app crash.
Normal ADB warnings and errors replaced per-packet tracing in 8db9bae7; this
reduced logging overhead but did not resolve the transport loss. No specific
upstream regression or root cause has been proven.

The second run's tall replay completed all six cases, with zero errors or skips,
but its post-test screenshot used the logical 411x891 dimensions. Android had
returned the physical 412x891 composition size before the test. Both independent
`wm size` readbacks correctly reported physical 412x891 and override 411x891.
Commit 1381ebc3 records capture space and accepts only those two explicitly
declared screenshot dimensions. It still requires exact logical viewport proof
before and after the unchanged test file, complete PNG data, successful capture
exit, full logcat coverage and successful device health. It does not retry a
test, reconnect a failed invocation or alter its recorded result.

Verification: 44 final-runner tests and six ownership tests passed. A separate
recheck of the original pre/post PNG bytes reproduced physical and logical
capture spaces under the new checker; the original run remains failed.
Run 34549031300 was dispatched with tooling 1381ebc3 to rerun all fifteen cases.
Its final native result must be read before certifying this gate.

The strict-16KB lane separately handles the documented adbd root restart response
by waiting for reconnection and requiring actual uid 0. It rejects other errors
and non-root guests. Selective run 34545389697 passed real 16384-byte pages,
AAB-derived installation, cold launch, Maestro onboarding and cleanup. Runs
34546671574 and 34549031300 also passed that strict lane. These disposable-signed
derived APK checks do not prove Play-signing, real authentication or purchases.
