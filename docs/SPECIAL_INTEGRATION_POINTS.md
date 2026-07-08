# Special Integration Points

This file maps runtime integrations to canonical homes in this repository.

## Core wiring map

- Riverpod: `lib/main.dart`, `lib/core/observers/riverpod_observer.dart`, `lib/state/providers/*`, `lib/data/di/*_providers.dart`
- GoRouter: `lib/app/router/app_router.dart`, `lib/app/router/route_paths.dart`, `lib/app/router/route_guards.dart`, `lib/app/navigation_shell.dart`
- Firebase: `lib/system/firebase/firebase_bootstrap.dart`, `lib/firebase_options.dart`, called from `lib/main.dart`
- Supabase: `lib/data/services/supabase_client_service.dart`, used from `lib/main.dart` and client read from `lib/data/di/storage_providers.dart`
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
