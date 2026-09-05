# Local production configuration

ChronoSpark supports an explicit device-local profile mode for Android production,
independently of production/debug and QA access. Cloud remains the default. Select local mode
through `tool/local_production_defines.json`; a bundled `.env` cannot change
the compiled backend mode.

```powershell
dart run scripts/validate_production_config.dart --platform=android --defines=tool/local_production_defines.json
flutter build apk --release --no-pub --dart-define-from-file=tool/local_production_defines.json
```

On a memory-constrained Windows build machine, the same release can be built
with process-local Gradle limits. This does not change app configuration or
the repository's normal Gradle settings:

```powershell
$env:GRADLE_OPTS = '-Dorg.gradle.jvmargs="-Xmx2048m -XX:MaxMetaspaceSize=768m -XX:ReservedCodeCacheSize=128m -XX:+UseSerialGC" -Dorg.gradle.workers.max=2 -Dorg.gradle.project.kotlin.compiler.execution.strategy=in-process'
flutter build apk --release --no-pub --dart-define-from-file=tool/local_production_defines.json
```

The Android build reads the same encoded Dart defines. An omitted mode keeps
the cloud default; conflicting or invalid mode values fail the build.
Local mode skips Google-services and Crashlytics processing, removes native
Firebase auto-initialization and release Internet permission, uses an explicit
local plugin allowlist before plugins can attach, and retains
release signing requirements. Existing private signing files are not changed.
Cloud builds retain their Google-services and account-backend requirements.
Apple local builds are blocked before native compilation until equivalent
plugin registration and Xcode validation are implemented. Dart host tests do
not establish native support on other platforms.

Local production does not enable mock login, tester privileges, fake premium
entitlements, or disabled-paywall QA overrides. Offline planning, tasks,
reflection, profile data, local backups, and local notifications use normal
production storage and feature rules. Purchases, external AI, cloud sync,
cloud recovery, telemetry upload, push messaging, and platform speech are
unavailable. Operating-system accessibility tools remain under user control.

A local profile has a random persistent device profile ID and a separate
account namespace. It does not have a verified email or cloud access token.
Opening a local profile never claims preserved cloud or unowned legacy data.
Permanent local deletion requires explicit confirmation, blocks profile
writes, clears the profile's own data and schedules, and removes the identity
only after cleanup. Interrupted deletion remains recoverable by retrying.
Closing a profile preserves its local data for reopening on the same device.

Local data is not an online account backup. Users should export and safely
retain local backups where available before clearing app storage, uninstalling,
or replacing their device. Switching build modes does not migrate cloud data
or import it into a local profile.

Validation must run in both default cloud and explicit local configurations.
The local profile, lifecycle, readiness, startup service guards, deletion
failure/retry, and absence of platform service calls are host-test boundaries.
A release artifact's merged manifest must independently show no Internet
permission or Firebase initialization component. A physical-device test,
store submission, or production service deployment is a separate action.
