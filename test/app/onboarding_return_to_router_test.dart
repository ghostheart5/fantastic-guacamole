import 'dart:async';

import 'package:fantastic_guacamole/app/router/app_router.dart';
import 'package:fantastic_guacamole/app/router/route_access_policy.dart';
import 'package:fantastic_guacamole/app/router/route_guards.dart' as guards;
import 'package:fantastic_guacamole/app/router/route_paths.dart';
import 'package:fantastic_guacamole/config/env.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/repositories/shared_preferences_onboarding_repository.dart';
import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/notification_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
import 'package:fantastic_guacamole/features/auth/screens/auth_gate.dart';
import 'package:fantastic_guacamole/features/onboarding/ui/onboarding_screen.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/state/services/intelligence_service.dart';
import 'package:fantastic_guacamole/state/state/intelligence_state.dart';
import 'package:fantastic_guacamole/state/providers/onboarding_preferences_provider.dart';
import 'package:fantastic_guacamole/state/providers/smart_planner_first_value_provider.dart';
import 'package:fantastic_guacamole/tutorial/adaptive_guidance.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _authenticatedProvider = NotifierProvider<_TestBoolNotifier, bool>(
  _TestBoolNotifier.new,
);

final _accountProvider = NotifierProvider<_TestAccountNotifier, String>(
  _TestAccountNotifier.new,
);

class _TestAccountNotifier extends Notifier<String> {
  @override
  String build() => 'onboarding-return-to-test-user';
  void set(String value) => state = value;
}

class _TestBoolNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

void main() {
  final String welcomeEntryLabel = Env.isLocalMode
      ? 'CONTINUE TO PROFILE'
      : 'CONTINUE TO LOGIN';
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

      await tester.tap(find.text(welcomeEntryLabel));
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
      await tester.tap(find.byKey(const Key('first-value-show-choice')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      final Uri uri = harness.router.routeInformationProvider.value.uri;
      expect(uri.path, RoutePaths.timeline);
      expect(uri.queryParameters['day'], '2026-08-29');
      expect(uri.fragment, 'block-7');
      expect(harness.container.read(appFlowProvider), AppView.timeline);
    },
  );

  testWidgets('quick exit names and opens the protected Settings destination', (
    tester,
  ) async {
    final harness = await _pumpRouter(tester);
    const destination = '/settings?section=planning#learning';
    harness.router.go(destination);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    _expectLocation(
      harness,
      path: RoutePaths.onboarding,
      returnTo: destination,
    );
    await tester.tap(find.text(welcomeEntryLabel));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    _expectLocation(harness, path: RoutePaths.login, returnTo: destination);
    harness.container.read(_authenticatedProvider.notifier).set(true);
    harness.router.refresh();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    _expectLocation(
      harness,
      path: RoutePaths.onboarding,
      returnTo: destination,
    );
    final quickExit = find.byKey(const Key('first-value-skip-top'));
    expect(
      find.descendant(
        of: quickExit,
        matching: find.text('CONTINUE TO REQUESTED PAGE'),
      ),
      findsOneWidget,
    );
    expect(find.text('Go to Today'), findsNothing);
    await tester.tap(quickExit);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    final uri = harness.router.routeInformationProvider.value.uri;
    expect(uri.path, RoutePaths.settings);
    expect(uri.queryParameters['section'], 'planning');
    expect(uri.fragment, 'learning');
    expect(harness.container.read(smartPlannerFirstValueProvider), isNull);
    expect(harness.container.read(onboardingCompleteProvider), isTrue);
  });

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

    await tester.tap(find.text(welcomeEntryLabel));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    _expectLocation(harness, path: RoutePaths.login);

    harness.container.read(_authenticatedProvider.notifier).set(true);
    harness.router.refresh();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    _expectLocation(harness, path: RoutePaths.onboarding);
    final quickExit = find.byKey(const Key('first-value-skip-top'));
    expect(
      find.descendant(of: quickExit, matching: find.text('Go to Today')),
      findsOneWidget,
    );
    await tester.tap(quickExit);
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

    await tester.tap(find.text(welcomeEntryLabel));
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

  for (final sameAccount in [false, true]) {
    testWidgets(
      'account ${sameAccount ? 'generation' : 'namespace'} change during guidance pause stops completion',
      (tester) async {
        final pause = _PausedGuidance();
        final harness = await _pumpRouter(tester, guidance: pause);
        await tester.tap(find.text(welcomeEntryLabel));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        harness.container.read(_authenticatedProvider.notifier).set(true);
        harness.router.refresh();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.tap(find.byKey(const Key('first-value-skip-top')));
        await tester.pump();
        expect(pause.started, isTrue);
        final boundary = harness.container.read(
          authSessionBoundaryProvider.notifier,
        );
        final nextAccount = sameAccount
            ? 'onboarding-return-to-test-user'
            : 'replacement-account';
        final generation = boundary.begin(
          userId: nextAccount,
          isTransitioning: true,
        );
        boundary.complete(generation);
        harness.container.read(_accountProvider.notifier).set(nextAccount);
        await tester.pump();
        pause.finish.complete();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        _expectLocation(harness, path: RoutePaths.onboarding);
        expect(harness.container.read(onboardingCompleteProvider), isFalse);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool(onboardingCompleteStorageKey), isNot(true));
        final namespace = AccountStorageScope.authenticated(
          nextAccount,
        ).v2Namespace;
        expect(
          prefs.getBool('onboarding_profile_complete_v1.$namespace'),
          isNot(true),
        );
        expect(
          tester
              .widget<TextButton>(find.byKey(const Key('first-value-skip-top')))
              .onPressed,
          isNotNull,
        );
      },
    );
  }

  testWidgets(
    'account switch during global completion cannot complete the replacement account',
    (tester) async {
      final preferences = _PausedPreferences();
      final harness = await _pumpRouter(tester, preferences: preferences);
      await tester.tap(find.text(welcomeEntryLabel));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      harness.container.read(_authenticatedProvider.notifier).set(true);
      harness.router.refresh();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.byKey(const Key('first-value-show-choice')));
      await tester.pump();
      expect(preferences.started, isTrue);
      final boundary = harness.container.read(
        authSessionBoundaryProvider.notifier,
      );
      final generation = boundary.begin(
        userId: 'replacement-account',
        isTransitioning: true,
      );
      boundary.complete(generation);
      harness.container
          .read(_accountProvider.notifier)
          .set('replacement-account');
      await tester.pump();
      preferences.finish.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      _expectLocation(harness, path: RoutePaths.onboarding);
      expect(harness.container.read(onboardingCompleteProvider), isFalse);
      final prefs = await SharedPreferences.getInstance();
      final namespace = AccountStorageScope.authenticated(
        'replacement-account',
      ).v2Namespace;
      expect(
        prefs.getBool('onboarding_profile_complete_v1.$namespace'),
        isNot(true),
      );
      expect(harness.container.read(smartPlannerFirstValueProvider), isNull);
    },
  );
}

Future<_RouterHarness> _pumpRouter(
  WidgetTester tester, {
  bool enableMockLogin = false,
  AdaptiveGuidanceNotifier? guidance,
  _PausedPreferences? preferences,
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
      accountStorageScopeProvider.overrideWith(
        (ref) => AccountStorageScope.authenticated(ref.watch(_accountProvider)),
      ),
      domainTaskRepositoryProvider.overrideWithValue(_EmptyTasks()),
      if (guidance != null)
        adaptiveGuidanceProvider.overrideWith(() => guidance),
      if (preferences != null)
        onboardingPreferencesRepositoryProvider.overrideWithValue(preferences),
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

class _EmptyTasks implements ITaskRepository {
  @override
  Future<List<TaskEntity>> getAllTasks() async => [];
  @override
  Future<TaskEntity?> getTaskById(String id) async => null;
  @override
  Future<void> saveTask(TaskEntity task) async =>
      throw UnsupportedError('read-only fixture');
  @override
  Future<void> deleteTask(String id) async =>
      throw UnsupportedError('read-only fixture');
}

class _PausedGuidance extends AdaptiveGuidanceNotifier {
  final finish = Completer<void>();
  bool started = false;
  @override
  Future<AdaptiveGuidanceState> build() async => const AdaptiveGuidanceState(
    milestones: {},
    counts: {},
    skippedLessons: {},
    completedLessons: {},
  );
  @override
  Future<void> later(GuidanceLessonId lesson) async {
    started = true;
    await finish.future;
  }
}

class _PausedPreferences extends SharedPreferencesOnboardingRepository {
  final finish = Completer<void>();
  bool started = false;
  @override
  Future<void> markOnboardingComplete({required int contentVersion}) async {
    started = true;
    await finish.future;
  }
}
