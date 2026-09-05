# Special Integration Points

This file maps runtime integrations to canonical homes in this repository.

## Core wiring map

- Riverpod: `lib/main.dart`, `lib/core/observers/riverpod_observer.dart`, `lib/state/providers/*`, `lib/data/di/*_providers.dart`
- GoRouter: `lib/app/router/app_router.dart`, `lib/app/router/route_paths.dart`, `lib/app/router/route_guards.dart`, `lib/app/navigation_shell.dart`
- Firebase: `lib/system/firebase/firebase_bootstrap.dart`, `lib/firebase_options.dart`, called from `lib/main.dart`
- Supabase: `lib/data/services/supabase_client_service.dart`, used from `lib/main.dart` and client read from `lib/state/providers/storage_providers.dart`
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
	- Enable only owner-approved Auth providers after their configuration is verified.
	- Retain `chronospark://auth-callback` as the Android callback and current
	  production Site URL. Signup, confirmation resend and password-reset email
	  requests currently depend on that Site URL when no explicit redirect is sent.
	- Add other redirect URLs only for verified, owner-approved callback consumers.
	  Do not copy old domain/localhost examples into production. The existing
	  `https://chronospark.app/app/auth/callback` entry remains preserved while
	  domain work is deferred; its presence is not working-link evidence.
	- Do not add GitHub Pages informational/legal pages as authentication callbacks.
	  The current Pages site is not a verified web authentication client.
	- Live allowlist inventory and pending legacy-consumer decisions are recorded in
	  `docs/engineering/PHASE_2_BACKEND_HARDENING_20260904.md`.
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
	- Use the Supabase Auth provider callback shown in its dashboard, not the app's
	  custom-scheme redirect. For the current project this is
	  `https://qpwhuckyirnqtmvhpede.supabase.co/auth/v1/callback`.
- GitHub OAuth:
	- Create OAuth App in GitHub Developer Settings.
	- Set Authorization callback URL to the Supabase Auth provider callback above.
	- Paste GitHub Client ID/Secret into Supabase Auth > Providers > GitHub.

The provider callback returns control to Supabase; the approved app redirect then
returns control to ChronoSpark. Do not swap these two destinations. Confirm the
callback displayed by Supabase before any separately approved provider change.
Reference: [Supabase GitHub OAuth callback setup](https://supabase.com/docs/guides/auth/social-login/auth-github).
