import 'package:fantastic_guacamole/app/router/app_router.dart';
import 'package:fantastic_guacamole/app/router/route_guards.dart' as guards;
import 'package:fantastic_guacamole/app/router/route_paths.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/domain/entities/notification_entity.dart';
import 'package:fantastic_guacamole/features/notifications/ui/notification_screen.dart';
import 'package:fantastic_guacamole/features/onboarding/ui/onboarding_screen.dart';
import 'package:fantastic_guacamole/state/core/app_providers.dart';
import 'package:fantastic_guacamole/state/providers/access_provider.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/billing_availability_provider.dart';
import 'package:fantastic_guacamole/state/providers/intelligence_provider.dart';
import 'package:fantastic_guacamole/state/state/intelligence_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _setupComplete = NotifierProvider<_TestBool, bool>(_TestBool.new);
final _storageLocked = NotifierProvider<_TestBool, bool>(_TestBool.new);

void main() {
  for (final settleWhileLocked in [false, true]) {
    testWidgets(
      settleWhileLocked
          ? 'real router resumes completion refresh after storage lock detaches it'
          : 'real router reacts to completed setup without explicit navigation',
      (tester) async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        tester.view.physicalSize = const Size(1440, 2560);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final container = ProviderContainer(
          overrides: [
            guards.authenticatedGuardProvider.overrideWithValue(true),
            guards.onboardingWelcomeCompleteGuardProvider.overrideWithValue(
              true,
            ),
            guards.onboardingCompleteGuardProvider.overrideWith(
              (ref) => ref.watch(_setupComplete),
            ),
            accountStorageScopeProvider.overrideWithValue(
              AccountStorageScope.authenticated('router-refresh-profile'),
            ),
            intelligenceStateProvider.overrideWithValue(_intelligence),
            internalAdvisorAccessProvider.overrideWithValue(false),
            subscriptionPurchasingEnabledProvider.overrideWithValue(false),
            notificationProvider.overrideWith(_EmptyNotifications.new),
            automationNotificationsProvider.overrideWith(
              (ref) async => const <NotificationEntity>[],
            ),
          ],
        );
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          container.dispose();
        });
        container.read(onboardingWelcomeCompleteProvider.notifier).set(true);
        final router = container.read(appRouterProvider);
        // Establish one protected pending destination before mounting. All
        // subsequent redirect progress must come from provider refreshes.
        router.go(
          Uri(
            path: RoutePaths.onboarding,
            queryParameters: {'returnTo': RoutePaths.notifications},
          ).toString(),
        );
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const _RouterOrStorageLock(),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(
          router.routeInformationProvider.value.uri.path,
          RoutePaths.onboarding,
        );
        expect(find.byType(OnboardingScreen), findsOneWidget);

        if (settleWhileLocked) {
          container.read(_storageLocked.notifier).set(true);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 20));
          expect(find.text('Storage transition fixture'), findsOneWidget);
          expect(find.byType(OnboardingScreen), findsNothing);
        }
        container.read(_setupComplete.notifier).set(true);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 20));
        if (settleWhileLocked) {
          container.read(_storageLocked.notifier).set(false);
          await tester.pump();
        }
        await tester.pump(const Duration(milliseconds: 600));

        expect(
          container.read(appRouterProvider),
          same(router),
          reason:
              'A storage lock must retain the same router and pending destination.',
        );
        expect(
          router.routeInformationProvider.value.uri.path,
          RoutePaths.notifications,
          reason:
              'A completed guard must release setup without router.go, refresh, or a second setup tap.',
        );
        expect(find.byType(OnboardingScreen), findsNothing);
        expect(find.byType(NotificationsPage), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

class _RouterOrStorageLock extends ConsumerWidget {
  const _RouterOrStorageLock();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Match AppRoot's subscription lifecycle: the lock branch returns before
    // watching appRouterProvider, then the ready branch watches it again.
    if (ref.watch(_storageLocked)) {
      return const MaterialApp(
        home: Scaffold(body: Text('Storage transition fixture')),
      );
    }
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(routerConfig: router);
  }
}

class _TestBool extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

class _EmptyNotifications extends NotificationNotifier {
  @override
  List<NotificationEntity> build() => const <NotificationEntity>[];
}

const _intelligence = IntelligenceState(
  environment: EnvironmentState(
    appName: 'Axiomara',
    appFlavor: 'qa',
    isProduction: false,
    isSupabaseConfigured: false,
    isLocalMode: true,
  ),
  flags: FeatureFlagsState(
    verboseLogs: false,
    analyticsEnabled: false,
    mockMode: false,
    mockLoginEnabled: false,
    paywallDisabled: false,
    testerFullAccess: false,
  ),
  auth: AuthStateSnapshot(hasMockSignIn: false, hasAuthenticatedUser: true),
  mockLogin: MockLoginConfigState(email: '', password: ''),
);
