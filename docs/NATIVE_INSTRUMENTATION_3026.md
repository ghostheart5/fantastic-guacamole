# Build 3026 native transport repair

Candidate source: `e78001c20d0fa0a7a954bb0fa1aa9fc5237c96f9`.
Signed candidate run: `34605500439`.

Validation run `34606916292` lost ADB connectivity as the Planner test's
Flutter VM service started and the host attempted DDS attachment. No Planner
assertion executed. Continuous logs contain no preceding app fatal signal.
The original failure remains a failed gate; emulator pinning alone did not
make this transport reliable. The precise emulator/ADB root cause is unproven.

The fixture lane now uses Flutter's documented `FlutterTestRunner` and AndroidX
`AndroidJUnitRunner`. An explicit Gradle init script adds a Java androidTest
harness from this tooling checkout, restricted against release build tasks.
The unchanged Dart target and test APK compile before any emulator boots.
No `flutter test -d`, DDS session, retry, reconnection, per-test data reset, or
test selection/filtering occurs inside the invocation.

The five independent host/guest boundaries and existing 15 Dart cases remain.
Flutter's custom Java runner discovers one container but reports each Dart
test result. The parser therefore checks every named start/finish pair,
unique identities, exact maintained counts, zero failure/skip statuses, and
the terminal JUnit and instrumentation results. The aggregation job reparses
the retained raw output and checks its hash, APK preparation identity, clean
source provenance, continuous logs, viewport captures, and owned cleanup.
Windows canonical test manifests retain their original runner and schema.

This is fixture integration evidence. It does not replace signed-AAB launch,
Play Billing, owner-data preservation, or reviewer-access device validation.
The signed candidate bytes are unchanged.

References:
- https://docs.flutter.dev/testing/integration-tests#test-in-firebase-test-lab-android
- Flutter 3.44.6 `packages/integration_test/README.md`, Android Device Testing
- https://developer.android.com/jetpack/androidx/releases/test

Local adversarial runner/provenance/cleanup validation: 67 tests passed.
Hosted execution remains required before accepting this repair.

Run `34609928003` rejected the first harness during compilation: AndroidX
runner1.7.0/rules1.7.0 conflicted with AGP's consistent-resolution constraints
from Flutter's existing debug runtime (runner1.3.0/rules1.2.0). The harness now
initially matched those versions. Source inspection then identified the older
monitor's legacy broadcast-receiver registration, which is unsuitable for the
current target-SDK requirements. Run `34611303641` was canceled during setup/
compilation before accepting any result. The final overlay aligns runner1.7.0
and rules1.7.0 in BOTH debugImplementation and androidTestImplementation. This
changes the fixture-only test-library graph explicitly, without changing the
canonical checkout, app release dependencies or signed AAB. The failed first
preparation and canceled comparison supply no native pass.

Run `34611575564` compiled the aligned harness successfully. Its persistence
host passed, but other hosts failed during SDK image provisioning, before
starting a guest. One download failed; others returned success without the
expected image files under ANDROID_HOME. SDK provisioning now supplies an
explicit resolved SDK root and requires five nonempty image files. At most
three setup/download attempts occur before any emulator or application test.
Each attempt records command success, file sizes, installed packages and disk
state on failure. Existing image API, ABI, tag and revision checks remain.
The runner/provenance/cleanup suite now passes 70 tests. Full hosted matrix
acceptance is still pending; a single persistence host is not a matrix pass.

Run34614660995 proved the SDK Manager partial-install state: successful exit
and installed revision7 metadata, but only vendor.img present among the five
required files, unchanged over three attempts. The host had76GB available.
When that exact state persists, the gate now downloads Google's pinned
API36 revision7 archive, checks its published1,895,447,397-byte length and
SHA1c6bf44bdcd885bb902b4ba752d111a073ad7a817, and records a computed SHA256.
It validates every archive path before extraction, checks ZIP CRCs during
streaming, and restores only that image's directory on a disposable hosted
SDK. Existing API/ABI/tag/revision and five-file checks still apply. This is
setup repair before guest creation, not an application-test retry.
Official pin source (read September11):
https://dl.google.com/android/repository/sys-img/google_apis/sys-img2-4.xml
Local runner/provenance/cleanup/archive checks:74 passed.
