# Axiomara user-behavior repairs

This repair branch preserves the app's existing authentication, purchase, history,
recurrence, and progression policies. It changes the behavior found during the
October user-journey retest:

- Welcome wording points to the actual login or setup destination. Notification permission
  explains the request before invoking Android's prompt, with a separate settings
  recovery path when permission remains off.
- Habit reminders follow the selected daily, weekly, or monthly cadence and skip
  a completed period. The existing first-active-habit reminder policy remains.
- Daily reminders preserve the selected local wall-clock hour across a daylight
  saving transition. The notification plugin respects the first allowed repeat
  date. Delivery still uses Android's approximate alarm mode.
- Skip resolves the canonical task even when advisory fatigue filtering removes
  it from recommendations. Account and terminal-action protections remain.
- Nexus displays the selected future task occurrence instead of implying it is
  ready to execute now.
- Library supports management of unscheduled tasks, labels skipped tasks
  correctly, and removes unsupported terminal controls. Canceled records are
  read-only. Library and Timeline removal explain retained canceled history.

## Reproduce host validation

Use the Flutter version pinned in CI (3.44.6), install the locked dependencies, and
run each required compile profile separately:

```sh
flutter pub get --enforce-lockfile
flutter analyze --fatal-infos
flutter test --no-pub --exclude-tags=local-public-policy
flutter test --no-pub --dart-define-from-file=tool/local_public_policy_test_defines.json test/release/local_public_policy_planner_test.dart
flutter test --no-pub --dart-define-from-file=tool/qa_defines.json test/config/env_mode_resolution_test.dart
```

The default suite excludes the tagged local-policy file because that file requires
its own compile-time configuration. It is executed in the second test command,
not omitted from validation. Focused tests overlap the full suite; their counts
must not be added to it. The committed CI workflow already runs these profiles.

The notification dependency is intentionally vendored with its upstream hash
manifest, license, local patch notes, and Java regression tests. Do not replace it
with an upstream release without checking the first-allowed-repeat-date behavior.
Its own `analysis_options.yaml` establishes a separate package boundary using
ordinary Dart inference for its upstream platform-channel code. Default Dart
diagnostics remain enabled and no vendor source files are excluded. Axiomara's
strict application analysis policy is unchanged.

Authored Patrol journeys and navigation helpers are included. Patrol generates
`patrol_test/test_bundle.dart` for a selected device run; that generated file is
excluded from this repair commit.

## Native verification and limits

The computer emulator uses the normal app entry point with the existing local QA
profile configuration. Mock login, tester full access, and paywall bypass are off.
Google credentials are not required for these local checks. No production
authentication code or stored progression is bypassed or injected.

Retained UI evidence covers first-task guidance, one reviewed task creation and
completion, weekly/monthly habit controls, notification consent and native
registrations, ordinary Skip without visible XP gain, and Library management.
The final Library task completed once; visible progress changed from 25 to 50 XP
and one to two completed tasks, and persisted after restarting the app.

Task removal cancels the canonical record so sync can retain its deletion history;
it is not physical erasure. Real-repository regression coverage verifies that
retention, while UI checks distinguish Cancel from confirmed removal.

These are bounded source, host, and local-device results. They do not establish
whole-app acceptance, a new emulator journey to level 20, authenticated cloud
sync/recovery, renewal/refund/cross-device purchases, timed notification delivery
under Doze/reboot, or a native clock-change experiment. Prior Play test purchases
are separately recorded and used test payments only. This branch is not a Google
Play publication.
