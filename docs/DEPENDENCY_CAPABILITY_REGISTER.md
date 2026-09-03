# Dependency Capability Register

This register assigns an owner and review boundary to direct packages with
platform permissions, remote data, monetization, or user-generated content.
The package versions remain authoritative in `pubspec.yaml` and
`pubspec.lock`; this document records why each capability exists and what must
be reviewed before upgrading or removing it.

| Package family | ChronoSpark surface | Data/capability boundary | Review owner | Removal condition |
|---|---|---|---|---|
| `supabase_flutter` | GhostHeart5 auth, account data, Edge Functions | Authenticated user data; publishable client key only | Data/backend owner | Remove after all GhostHeart5 repositories/functions are retired |
| `firebase_core`, `firebase_analytics`, `firebase_crashlytics`, `firebase_messaging`, `firebase_remote_config` | Crash reporting, analytics, messaging, remote config | Diagnostics, notification tokens, feature flags | Mobile/release owner | Remove only after replacement telemetry and notification paths are verified |
| `in_app_purchase*` | Billing/subscription boundary | Store purchase receipts and entitlement state | Monetization owner | Remove after entitlements are migrated and receipt verification is retired |
| `flutter_secure_storage`, `encrypt`, `crypto` | Local credential and sensitive-state protection | Encrypted local values; no server secret storage | Privacy owner | Remove only after an equivalent secure storage review |
| `flutter_local_notifications`, `timezone`, `permission_handler` | Local reminders and permission flow | Scheduling metadata and OS permissions | Notifications owner | Remove after local reminder cancellation and permission tests pass |
| `speech_to_text`, `audioplayers`, `audio_session` | Voice and audio assistance | Microphone/audio streams and playback | Accessibility owner | Remove only after voice/audio surfaces are explicitly retired |
| `share_plus` | Creator sharing | User-initiated outbound shares | Creator owner | Remove after sharing entry points are removed |

Before a dependency upgrade, attach the generated dependency report to the
release evidence and record advisory status, license, platform compatibility,
and the owner decision. Never add a direct package without adding its row or a
documented reason it is intentionally outside this register.

## Manifest cleanup — 2026-09-03

Direct packages with no Dart imports or generated outputs were removed from the
manifest, including unused media, storage, Firebase, annotation, and generator
packages. The dependency audit now checks direct-package reachability and this
capability register so the stale entries cannot return silently.
