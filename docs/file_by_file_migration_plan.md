# ChronoSpark File-by-File Migration Plan

## Phase 1 - Stabilize Current Behavior

- [lib/main.dart](../lib/main.dart): keep startup bootstrap, but route through the new router-backed `AppRoot`.
- [lib/app/app_root.dart](../lib/app/app_root.dart): use `MaterialApp.router` and keep startup error overlay.
- [lib/app/router/app_router.dart](../lib/app/router/app_router.dart): preserve current screens behind GoRouter.
- [lib/app/router/route_guards.dart](../lib/app/router/route_guards.dart): read onboarding, auth, and premium access from live providers.
- [lib/features/auth/screens/auth_gate.dart](../lib/features/auth/screens/auth_gate.dart): retain until router-auth parity is complete.
- [lib/features/paywall/ui/paywall_page.dart](../lib/features/paywall/ui/paywall_page.dart): keep unlocked-for-testing mode during migration.

## Phase 2 - Replace Navigation Layer

- [lib/app/navigation_shell.dart](../lib/app/navigation_shell.dart): convert bottom navigation into a GoRouter shell route target.
- [lib/core/navigation/app_router.dart](../lib/core/navigation/app_router.dart): deprecate in favor of `lib/app/router/app_router.dart`.
- [lib/core/extensions/context_extensions.dart](../lib/core/extensions/context_extensions.dart): remove imperative navigation helpers after GoRouter parity.
- [lib/ui/widgets/chronospark_bottom_nav.dart](../lib/ui/widgets/chronospark_bottom_nav.dart): rebind taps to GoRouter destinations.

## Phase 3 - Service Extraction

- [lib/data/services/auth_service.dart](../lib/data/services/auth_service.dart): move into `lib/services/auth/`.
- [lib/features/notifications/notification_scheduler.dart](../lib/features/notifications/notification_scheduler.dart): move into `lib/services/notifications/`.
- [lib/features/paywall/repositories/paywall_repository.dart](../lib/features/paywall/repositories/paywall_repository.dart): move into `lib/services/monetization/`.
- [lib/state/controllers/ai_controller.dart](../lib/state/controllers/ai_controller.dart): split orchestration into `lib/services/ai/`.
- [lib/data/services/settings_service.dart](../lib/data/services/settings_service.dart): move persistence logic into `lib/services/storage/` and keep only view-model adapters in state.

## Phase 4 - Feature Modularization

- [lib/features/auth](../lib/features/auth): keep screen and state files together under an auth module.
- [lib/features/home](../lib/features/home): split Smart Coach and shared cards into module-local widgets and controllers.
- [lib/features/settings](../lib/features/settings): split settings screen, actions, providers, and widgets into module-local layers.
- [lib/onboarding](../lib/onboarding): move onboarding flow into a module with route entry points.
- [lib/features/tasks](../lib/features/tasks): split trajectory screen, widgets, controllers, and summary models.
- [lib/features/notifications](../lib/features/notifications): split UI, repository, service, and scheduling responsibilities.

## Phase 5 - Platform Integration

- [lib/firebase](../lib/firebase): create Firebase auth/firestore/messaging/analytics bootstrap wrappers if Firebase becomes the platform standard.
- [lib/services/analytics](../lib/services/analytics): add event logging and user property tracking.
- [lib/services/voice](../lib/services/voice): centralize speech-to-text and TTS orchestration.
- [lib/services/monetization](../lib/services/monetization): implement Google Play Billing-backed subscriptions.

## High-Risk Files To Watch

- [android/key.properties](../android/key.properties)
- [lib/config/firebase_options.dart](../lib/config/firebase_options.dart)
- [lib/data/services/auth_service.dart](../lib/data/services/auth_service.dart)
- [lib/state/controllers/ai_controller.dart](../lib/state/controllers/ai_controller.dart)
- [lib/features/paywall/repositories/paywall_repository.dart](../lib/features/paywall/repositories/paywall_repository.dart)
- [lib/features/settings/ui/settings_screen.dart](../lib/features/settings/ui/settings_screen.dart)
