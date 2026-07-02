# ChronoSpark Migration Checklist

## Phase 1 - Inventory and Stabilization

- Keep current shell navigation alive in `lib/app/navigation_shell.dart`.
- Keep current route table alive in `lib/core/navigation/app_router.dart`.
- Preserve current auth bootstrap in `lib/main.dart` and `lib/data/services/auth_service.dart`.
- Preserve local notifications in `lib/features/notifications/notification_scheduler.dart`.
- Preserve AI/SI outputs in `lib/state/controllers/ai_controller.dart` and `lib/engine/si/*`.
- Preserve paywall QA bypass in `lib/config/paywall_config.dart` until live billing is ready.

## Phase 2 - Router Introduction

- Add GoRouter scaffold under `lib/app/router/`.
- Mirror existing routes before redirecting any live users.
- Add shell route for bottom navigation.
- Add route guards for onboarding, login, and premium routes.

## Phase 3 - Service Extraction

- Move auth orchestration to `lib/services/auth/`.
- Move notification orchestration to `lib/services/notifications/`.
- Move monetization to `lib/services/monetization/`.
- Move AI orchestration to `lib/services/ai/`.
- Move analytics to `lib/services/analytics/`.

## Phase 4 - Feature Modularization

- Split each screen into `screens/`, `widgets/`, `controllers/`, `models/`, and `feature_module.dart`.
- Start with auth, home, settings, onboarding, paywall, and AI.

## Phase 5 - Backend and Platform Migration

- Replace Supabase-auth naming drift with a single auth facade.
- Add Firebase Messaging and analytics if the platform standard becomes Firebase.
- Connect billing-backed subscriptions to Google Play Billing.

## High-Risk Files

- `android/key.properties`
- `lib/data/services/auth_service.dart`
- `lib/main.dart`
- `lib/app/navigation_shell.dart`
- `lib/core/navigation/app_router.dart`
- `lib/state/controllers/ai_controller.dart`
- `lib/features/paywall/repositories/paywall_repository.dart`
