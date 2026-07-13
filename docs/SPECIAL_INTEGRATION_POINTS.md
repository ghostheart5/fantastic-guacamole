# Special Integration Points

This file maps runtime integrations to canonical homes in this repository.

## Core wiring map

- Riverpod: `lib/main.dart`, `lib/core/observers/riverpod_observer.dart`, `lib/state/providers/*`, `lib/data/di/*_providers.dart`
- GoRouter: `lib/app/router/app_router.dart`, `lib/app/router/route_paths.dart`, `lib/app/router/route_guards.dart`, `lib/app/navigation_shell.dart`
- Firebase: `lib/system/firebase/firebase_bootstrap.dart`, `lib/firebase_options.dart`, called from `lib/main.dart`
- Supabase: `lib/data/services/supabase_client_service.dart`, used from `lib/main.dart` and client read from `lib/data/di/storage_providers.dart`
- Social auth (Google/GitHub via Supabase OAuth): `lib/data/services/auth_service.dart`, `lib/features/auth/screens/auth_gate.dart`, `lib/features/auth/ui/login_screen.dart`
- Hive: `lib/data/storage/hive_service.dart`, `lib/data/storage/hive_adapters.dart`, `lib/data/storage/hive_boxes.dart`, `lib/data/local/hive_storage.dart`
- SharedPreferences: `lib/data/storage/shared_prefs_service.dart`, `lib/data/local/shared_prefs_storage.dart`
- Secure storage: `lib/data/storage/secure_store.dart`
- Local notifications + timezone: `lib/system/notifications/notification_scheduler.dart` and timezone setup in `lib/main.dart`
- In-app purchase: `lib/data/repositories/google_play_paywall_repository.dart`, `lib/state/providers/paywall_provider.dart`, `lib/features/paywall/*`
- App links: `lib/app/router/deep_link_service.dart`, initialized early in `lib/main.dart`
- URL launcher: `lib/system/external_url_service.dart` (wrapper), can be consumed by settings/legal/help UI actions
- Connectivity: `lib/core/network/network_status_service.dart`

## Guardrails

- Keep redirects/guards centralized in `app_router.dart` and `route_guards.dart`.
- UI screens should not own route policy.
- Initialize one-time SDKs at startup (`main.dart` boot stages).

## Required runtime defines

- `CHRONOSPARK_SUPABASE_URL` = your Supabase project URL
- `CHRONOSPARK_SUPABASE_ANON_KEY` = your Supabase anon/publishable key
- `CHRONOSPARK_OAUTH_REDIRECT_URL` = OAuth callback URL (used for Google by default)
- `CHRONOSPARK_GITHUB_OAUTH_REDIRECT_URL` = GitHub-specific callback URL (optional; falls back to `CHRONOSPARK_OAUTH_REDIRECT_URL`)

## External console linkage checklist

- Supabase:
	- Enable Auth providers: Google and GitHub.
	- Add redirect URL(s) matching your app callback route.
	- Supabase redirect allowlist:
	  - `chronospark://auth-callback`
	  - `http://localhost:3000`
	  - `http://localhost:8080`
	  - `https://chronospark.ai`
	  - `https://www.chronospark.ai`
	- Authentication -> Providers:
	  - Google: paste Google Cloud OAuth Client ID and Client Secret.
	  - GitHub: paste GitHub OAuth App Client ID and Client Secret.
	- Authentication -> URL Configuration:
	  - Keep callback URLs aligned with `chronospark://auth-callback` for Android testing.
- Firebase:
	- Keep `lib/firebase_options.dart` aligned with the active Firebase project (`chronospark-app`).
	- Ensure Android/iOS app IDs in Firebase match package/bundle IDs used by this app.
- Google OAuth:
	- Create OAuth app/client in Google Cloud and connect it in Supabase Auth > Providers > Google.
	- Add the same callback URL used by `CHRONOSPARK_OAUTH_REDIRECT_URL`.
- GitHub OAuth:
	- Create OAuth App in GitHub Developer Settings.
	- Set Authorization callback URL to your app callback URL.
	- Paste GitHub Client ID/Secret into Supabase Auth > Providers > GitHub.
