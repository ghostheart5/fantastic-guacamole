import 'package:fantastic_guacamole/app/router/app_router.dart';
import 'package:fantastic_guacamole/app/router/route_access_policy.dart';
import 'package:fantastic_guacamole/app/router/route_guards.dart' as guards;
import 'package:fantastic_guacamole/app/router/route_paths.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/notification_entity.dart';
import 'package:fantastic_guacamole/features/auth/screens/auth_gate.dart';
import 'package:fantastic_guacamole/features/onboarding/ui/onboarding_screen.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/state/services/intelligence_service.dart';
import 'package:fantastic_guacamole/state/state/intelligence_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _authenticatedProvider = NotifierProvider<_TestBoolNotifier, bool>(
  _TestBoolNotifier.new,
);

class _TestBoolNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets(
    'protected returnTo keeps its query and fragment through every gate',
    (WidgetTester tester) async {
      final _RouterHarness harness = await _pumpRouter(tester);
      const String destination = '/timeline?day=2026-08-29#block-7';

      harness.router.go(destination);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      _expectLocation(
        harness,
        path: RoutePaths.onboarding,
        returnTo: destination,
      );
      expect(find.byType(OnboardingScreen), findsOneWidget);

      await tester.tap(find.text('CONTINUE TO LOGIN'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      _expectLocation(harness, path: RoutePaths.login, returnTo: destination);
      expect(find.byType(AuthGate), findsOneWidget);

      harness.container.read(_authenticatedProvider.notifier).set(true);
      harness.router.refresh();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      _expectLocation(
        harness,
        path: RoutePaths.onboarding,
        returnTo: destination,
      );
      await tester.tap(find.text('CONTINUE TO REQUESTED PAGE'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      final Uri uri = harness.router.routeInformationProvider.value.uri;
      expect(uri.path, RoutePaths.timeline);
      expect(uri.queryParameters['day'], '2026-08-29');
      expect(uri.fragment, 'block-7');
      expect(harness.container.read(appFlowProvider), AppView.timeline);
    },
  );

  testWidgets('hostile returnTo is rejected and skip falls back to Nexus', (
    WidgetTester tester,
  ) async {
    final _RouterHarness harness = await _pumpRouter(tester);
    final String hostileLocation = Uri(
      path: RoutePaths.onboarding,
      queryParameters: <String, String>{
        RouteAccessPolicy.returnToQueryParameter: 'https://evil.example/path',
      },
    ).toString();

    harness.router.go(hostileLocation);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('CONTINUE TO LOGIN'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    _expectLocation(harness, path: RoutePaths.login);

    harness.container.read(_authenticatedProvider.notifier).set(true);
    harness.router.refresh();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    _expectLocation(harness, path: RoutePaths.onboarding);
    await tester.tap(find.text('SKIP FOR NOW'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    _expectLocation(harness, path: RoutePaths.nexus);
  });

  testWidgets('Back from first-run login returns to the welcome step', (
    WidgetTester tester,
  ) async {
    final _RouterHarness harness = await _pumpRouter(
      tester,
      enableMockLogin: true,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('CONTINUE TO LOGIN'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    _expectLocation(harness, path: RoutePaths.login);
    expect(harness.container.read(onboardingWelcomeCompleteProvider), isTrue);
    expect(find.byType(PopScope<Object?>), findsOneWidget);
    expect(
      tester.widget<PopScope<Object?>>(find.byType(PopScope<Object?>)).canPop,
      isFalse,
    );

    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(harness.container.read(onboardingWelcomeCompleteProvider), isFalse);
    _expectLocation(harness, path: RoutePaths.onboarding);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(onboardingWelcomeCompleteStorageKey), isFalse);
  });
}

Future<_RouterHarness> _pumpRouter(
  WidgetTester tester, {
  bool enableMockLogin = false,
}) async {
  tester.view.physicalSize = const Size(1440, 2560);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final ProviderContainer container = ProviderContainer(
    overrides: [
      guards.authenticatedGuardProvider.overrideWith(
        (Ref ref) => ref.watch(_authenticatedProvider),
      ),
      guards.onboardingWelcomeCompleteGuardProvider.overrideWith(
        (Ref ref) => ref.watch(onboardingWelcomeCompleteProvider),
      ),
      guards.onboardingCompleteGuardProvider.overrideWith(
        (Ref ref) => ref.watch(onboardingCompleteProvider),
      ),
      intelligenceStateProvider.overrideWith((Ref ref) {
        if (enableMockLogin) {
          return IntelligenceState(
            environment: const EnvironmentState(
              appName: 'ChronoSpark',
              appFlavor: 'qa',
              isProduction: false,
              isSupabaseConfigured: false,
            ),
            flags: const FeatureFlagsState(
              verboseLogs: false,
              analyticsEnabled: false,
              mockMode: true,
              mockLoginEnabled: true,
              paywallDisabled: true,
              testerFullAccess: true,
            ),
            auth: AuthStateSnapshot(
              hasMockSignIn: ref.watch(_authenticatedProvider),
              hasAuthenticatedUser: false,
            ),
            mockLogin: const MockLoginConfigState(email: '', password: ''),
          );
        }
        return const IntelligenceService().fromRuntime(
          hasMockSignIn: ref.watch(_authenticatedProvider),
          hasAuthenticatedUser: false,
        );
      }),
      profileProvider.overrideWith(_TestProfileController.new),
      accountStorageScopeProvider.overrideWithValue(
        AccountStorageScope.authenticated('onboarding-return-to-test-user'),
      ),
      notificationProvider.overrideWith(_StaticNotifications.new),
      goalsProvider.overrideWith(_StaticGoals.new),
    ],
  );
  final GoRouter router = container.read(appRouterProvider);

  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
  });
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ),
  );

  return _RouterHarness(container: container, router: router);
}

void _expectLocation(
  _RouterHarness harness, {
  required String path,
  String? returnTo,
}) {
  final Uri uri = harness.router.routeInformationProvider.value.uri;
  expect(uri.path, path);
  expect(
    uri.queryParameters[RouteAccessPolicy.returnToQueryParameter],
    returnTo,
  );
}

class _RouterHarness {
  const _RouterHarness({required this.container, required this.router});

  final ProviderContainer container;
  final GoRouter router;
}

class _TestProfileController extends ProfileController {
  @override
  ProfileState build() => ProfileState();

  @override
  Future<void> updateName(String name) async {
    final String trimmed = name.trim();
    if (trimmed.isNotEmpty) state = state.copyWith(name: trimmed);
  }
}

class _StaticGoals extends GoalsNotifier {
  @override
  List<GoalEntity> build() => const <GoalEntity>[];
}

class _StaticNotifications extends NotificationNotifier {
  @override
  List<NotificationEntity> build() => const <NotificationEntity>[];
}
