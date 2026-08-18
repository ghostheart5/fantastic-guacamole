# Dependency Capability Register

This is the required review record for direct packages that handle accounts, user content, device permissions, payments, telemetry, or external communication. The package name and current constraint come from `pubspec.yaml`; the review owner is a role, not a personal credential.

| Package | Product surface | Permission or external capability | Data class | Review owner |
| --- | --- | --- | --- | --- |
| `supabase_flutter` | Auth, account sync, GhostHeart5 functions | Network and account session | Account identifiers, user-created planning data | Backend owner |
| `firebase_core`, `firebase_analytics`, `firebase_crashlytics`, `firebase_remote_config` | Diagnostics, telemetry, configuration | Network | Diagnostics, aggregate usage, remote settings | Reliability owner |
| `firebase_messaging` | Notifications | Push token and notification permission | Device messaging token | Mobile platform owner |
| `in_app_purchase`, `in_app_purchase_android` | Entitlements and purchase restoration | Google Play billing | Purchase and entitlement status | Monetization owner |
| `flutter_secure_storage` | Local secrets and session-adjacent state | Secure-device storage | Local protected app state | Security owner |
| `hive`, `hive_flutter`, `shared_preferences` | Local persistence, migrations, and preferences | Device storage | User-created planning data, settings, and local lifecycle state | Data-platform owner |
| `crypto` | Request signing, purchase verification, and integrity checks | Local cryptographic computation | Authentication and purchase integrity material | Security owner |
| `http` | Backend and external-service requests | Network | Request metadata and feature-specific payloads | Backend owner |
| `audioplayers` | Local feedback and voice-adjacent playback | Audio output | Packaged or generated audio | Voice-feature owner |
| `speech_to_text`, `flutter_tts` | Optional voice interaction | Microphone and speech services | User voice input and generated speech | Voice-feature owner |
| `permission_handler` | Runtime permission recovery | OS permission prompts | Permission state only | Mobile platform owner |
| `flutter_local_notifications` | Local reminders | Notification permission | Reminder content and scheduling metadata | Notifications owner |
| `app_links` | Auth and app deep links | Incoming URI handling | Link parameters | Auth owner |
| `connectivity_plus` | Offline and recovery UX | Network-state observation | Connectivity state | Reliability owner |
| `device_info_plus`, `package_info_plus` | Diagnostics context | Device/app metadata access | Device model, OS, app version | Reliability owner |
| `url_launcher` | Explicit outbound links | External application | User-selected URL | Product owner |

## Override register

| Override | Reason | Owner | Removal condition | Required review |
| --- | --- | --- | --- | --- |
| `path_provider_foundation: 2.5.1` | Windows native-assets hook fails when the workspace path contains spaces; [upstream 2.6.0 reference](https://pub.dev/packages/path_provider_foundation/changelog#260) | Mobile release | A clean resolution and supported-target build review pass without the pin | Every dependency upgrade cycle |

## Release dependency gate

Before a release candidate, the release owner records the date, resolver output, and reviewer in the release evidence—not in production code:

1. Run `flutter pub outdated` and review direct-package changes.
2. Run `flutter pub deps` for every package with a newly resolved version that affects an owned capability.
3. Review upstream changelogs, advisories, licenses, permissions, and platform notes for changed direct packages.
4. Reconfirm each row above, including the override removal condition.
5. Run the approved static analysis and test suite before accepting `pubspec.lock` changes.

Temporary developer-only experiments belong in an untracked `pubspec_overrides.yaml`, never in the committed override section.

Current resolver, license, advisory, and toolchain evidence is recorded in
`docs/DEPENDENCY_RELEASE_GATE_2026-08-16.md`.

## Current review note — 2026-08-16

`flutter pub outdated --no-dev-dependencies` identified a retracted transitive `build_daemon` version and compatible upgrades in the resolved graph. The compatible-resolution upgrade replaced the retracted version with `build_daemon 4.1.5`. Major-version candidates remain subject to their owner and platform-impact review; they are not silently accepted through a lockfile refresh.

The dependency-remediation pass removed bundled runtime dotenv loading, the
discontinued golden helper, unused direct capability packages, and unused code
generators. `state_notifier` now has an explicit tested major-version bound.
The foundation override remains because required transitive packages still
resolve through `path_provider`; removal still requires the supported-target
review above.
