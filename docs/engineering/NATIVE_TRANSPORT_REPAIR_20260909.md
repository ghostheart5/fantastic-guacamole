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
