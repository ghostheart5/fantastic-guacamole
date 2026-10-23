import 'dart:async';

import 'package:fantastic_guacamole/app/router/app_router.dart';
import 'package:fantastic_guacamole/app/router/route_guards.dart' as guards;
import 'package:fantastic_guacamole/app/router/route_paths.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_namespace.dart';
import 'package:fantastic_guacamole/data/models/auth_models.dart';
import 'package:fantastic_guacamole/data/services/local_profile_auth_service.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/features/onboarding/ui/onboarding_screen.dart';
import 'package:fantastic_guacamole/state/core/app_providers.dart';
import 'package:fantastic_guacamole/state/providers/account_onboarding_provider.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/auth_session_boundary_provider.dart';
import 'package:fantastic_guacamole/state/providers/intelligence_provider.dart';
import 'package:fantastic_guacamole/state/state/intelligence_state.dart';
import 'package:fantastic_guacamole/tutorial/adaptive_guidance.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'Go to Today persists setup across local profile close and cold reopen',
    (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        onboardingWelcomeCompleteStorageKey: true,
      });
      tester.view.physicalSize = const Size(1440, 2560);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = SecureStore(backend: InMemorySecureStoreBackend());
      LocalProfileAuthService makeService() => LocalProfileAuthService(
        store: store,
        onBeforeClosed: (_) async {},
        onProfileDeleted: (_) async {},
      );
      final firstService = makeService();
      final user = await firstService.createProfile();
      final scope = AccountStorageScope.authenticated(user.id);
      final first = _ReentryHarness(firstService);
      await first.openBoundary(user.id);
      await first.container.read(accountOnboardingCompleteProvider.future);
      first.container
          .read(onboardingWelcomeCompleteProvider.notifier)
          .set(true);
      await first.mount(tester);
      expect(find.text('Go to Today'), findsOneWidget);
      await tester.tap(find.byKey(const Key('first-value-skip-top')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(first.location, RoutePaths.nexus);
      expect(
        first.container.read(guards.onboardingCompleteGuardProvider),
        isTrue,
      );
      final prefs = await SharedPreferences.getInstance();
      final completionKey =
          'onboarding_profile_complete_v1.${scope.v2Namespace}';
      expect(prefs.getBool(completionKey), isTrue);
      await store.forAccount(scope).writeString('qa-sentinel', 'saved plan');
      final persistedPreferences = <String, Object>{
        for (final key in prefs.getKeys()) key: prefs.get(key)!,
      };

      await firstService.signOut();
      await first.waitForUser(null);
      first.closeBoundary();
      expect(first.container.read(guards.authenticatedGuardProvider), isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
      first.dispose();
      await firstService.dispose();
      SharedPreferences.setMockInitialValues(persistedPreferences);

      // Recreate both service and provider container while retaining the same
      // preferences and secure backend, just as a closed-profile cold launch.
      final reopenedService = makeService();
      await reopenedService.initialize();
      expect(reopenedService.currentUser, isNull);
      final reopened = _ReentryHarness(reopenedService);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        reopened.dispose();
        await reopenedService.dispose();
      });
      await reopened.waitForUser(null);
      reopened.closeBoundary();
      reopened.container
          .read(onboardingWelcomeCompleteProvider.notifier)
          .set(true);
      await reopened.mount(tester);
      expect(reopened.location, RoutePaths.login);
      final returnedUser = await reopenedService.openProfile();
      expect(returnedUser.id, user.id);
      await reopened.openBoundary(user.id);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      reopened.router.go(RoutePaths.timeline);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(reopened.location, RoutePaths.timeline);
      expect(find.byType(OnboardingScreen), findsNothing);
      expect(
        reopened.container.read(accountStorageScopeProvider).v2Namespace,
        scope.v2Namespace,
      );
      final reopenedPreferences = await SharedPreferences.getInstance();
      expect(reopenedPreferences.getBool(completionKey), isTrue);
      expect(
        await store.forAccount(scope).readString('qa-sentinel'),
        'saved plan',
      );

      // A transient unsafe storage generation must deny access, then restore
      // only this profile's persisted completion when its boundary is ready.
      final boundary = reopened.container.read(
        authSessionBoundaryProvider.notifier,
      );
      final generation = boundary.begin(userId: user.id, isTransitioning: true);
      expect(
        reopened.container.read(guards.authenticatedGuardProvider),
        isFalse,
      );
      expect(
        reopened.container.read(guards.onboardingCompleteGuardProvider),
        isFalse,
      );
      boundary.markStorageReady(
        generation,
        legacyOwnership: LegacyScopeOwnership.provenNotOwned,
      );
      boundary.complete(generation);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      reopened.router.go(RoutePaths.timeline);
      await tester.pump();
      expect(reopened.location, RoutePaths.timeline);
      expect(find.byType(OnboardingScreen), findsNothing);
    },
  );

  test(
    'different or incomplete local profile cannot inherit completed setup',
    () async {
      final completed = AccountStorageScope.authenticated('local-completed');
      SharedPreferences.setMockInitialValues(<String, Object>{
        'onboarding_profile_complete_v1.${completed.v2Namespace}': true,
        onboardingCompleteStorageKey: true,
      });
      for (final account in ['local-incomplete', 'local-different']) {
        final container = ProviderContainer(
          overrides: [
            accountStorageScopeProvider.overrideWithValue(
              AccountStorageScope.authenticated(account),
            ),
            accountLegacyOwnershipProvider.overrideWithValue(
              LegacyScopeOwnership.provenNotOwned,
            ),
          ],
        );
        try {
          expect(
            await container.read(accountOnboardingCompleteProvider.future),
            isFalse,
          );
          final redirect = computeAppRedirect(
            isAuthenticated: true,
            welcomeComplete: true,
            onboardingComplete: container
                .read(accountOnboardingCompleteProvider)
                .requireValue,
            location: RoutePaths.timeline,
          );
          expect(Uri.parse(redirect!).path, RoutePaths.onboarding);
        } finally {
          container.dispose();
        }
      }
    },
  );
}

class _ReentryHarness {
  _ReentryHarness(this.service) {
    container = ProviderContainer(
      overrides: [
        authUserProvider.overrideWith((ref) => service.authStateChanges()),
        intelligenceStateProvider.overrideWith(
          (ref) => IntelligenceState(
            environment: const EnvironmentState(
              appName: 'Axiomara',
              appFlavor: 'qa',
              isProduction: false,
              isSupabaseConfigured: false,
              isLocalMode: true,
            ),
            flags: const FeatureFlagsState(
              verboseLogs: false,
              analyticsEnabled: false,
              mockMode: false,
              mockLoginEnabled: false,
              paywallDisabled: false,
              testerFullAccess: false,
            ),
            auth: AuthStateSnapshot(
              hasMockSignIn: false,
              hasAuthenticatedUser:
                  ref.watch(authUserProvider).asData?.value != null,
            ),
            mockLogin: const MockLoginConfigState(email: '', password: ''),
          ),
        ),
        adaptiveGuidanceProvider.overrideWith(_QuietGuidance.new),
      ],
    );
    for (final provider in [
      guards.authenticatedGuardProvider,
      guards.onboardingCompleteGuardProvider,
      guards.onboardingWelcomeCompleteGuardProvider,
    ]) {
      subscriptions.add(
        container.listen<bool>(provider, (_, _) => refresh.update()),
      );
    }
    router = GoRouter(
      initialLocation: RoutePaths.onboarding,
      refreshListenable: refresh,
      redirect: (_, state) => computeAppRedirect(
        isAuthenticated: container.read(guards.authenticatedGuardProvider),
        welcomeComplete: container.read(
          guards.onboardingWelcomeCompleteGuardProvider,
        ),
        onboardingComplete: container.read(
          guards.onboardingCompleteGuardProvider,
        ),
        location: state.matchedLocation,
        uri: state.uri,
      ),
      routes: [
        GoRoute(
          path: RoutePaths.onboarding,
          builder: (_, state) => OnboardingScreen(
            completedLocation: state.uri.queryParameters['returnTo'],
          ),
        ),
        for (final path in [
          RoutePaths.login,
          RoutePaths.nexus,
          RoutePaths.timeline,
        ])
          GoRoute(
            path: path,
            builder: (_, _) => Scaffold(body: Text(path)),
          ),
      ],
    );
  }
  final LocalProfileAuthService service;
  late final ProviderContainer container;
  late final GoRouter router;
  final refresh = _RouterRefresh();
  final subscriptions = <ProviderSubscription<bool>>[];
  String get location => router.routeInformationProvider.value.uri.path;

  Future<void> waitForUser(String? id) async {
    final ready = Completer<void>();
    final subscription = container.listen<AsyncValue<User?>>(authUserProvider, (
      _,
      next,
    ) {
      if (next.asData != null &&
          next.asData!.value?.id == id &&
          !ready.isCompleted) {
        ready.complete();
      }
    }, fireImmediately: true);
    try {
      await ready.future;
    } finally {
      subscription.close();
    }
  }

  Future<void> openBoundary(String id) async {
    await waitForUser(id);
    final boundary = container.read(authSessionBoundaryProvider.notifier);
    final generation = boundary.begin(userId: id, isTransitioning: true);
    boundary.markStorageReady(
      generation,
      legacyOwnership: LegacyScopeOwnership.provenNotOwned,
    );
    boundary.complete(generation);
  }

  void closeBoundary() {
    final boundary = container.read(authSessionBoundaryProvider.notifier);
    final generation = boundary.begin(userId: null, isTransitioning: true);
    boundary.complete(generation, storageReady: false);
  }

  Future<void> mount(WidgetTester tester) => tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ),
  );

  void dispose() {
    router.dispose();
    for (final subscription in subscriptions) {
      subscription.close();
    }
    container.dispose();
    refresh.dispose();
  }
}

class _RouterRefresh extends ChangeNotifier {
  void update() => notifyListeners();
}

class _QuietGuidance extends AdaptiveGuidanceNotifier {
  @override
  Future<AdaptiveGuidanceState> build() async => const AdaptiveGuidanceState(
    milestones: {},
    counts: {},
    skippedLessons: {},
    completedLessons: {},
  );

  @override
  Future<void> later(GuidanceLessonId lesson) async {}
}
