import 'package:fantastic_guacamole/app/router/route_paths.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/models/auth_models.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
import 'package:fantastic_guacamole/l10n/chronospark_localizations.dart';
import 'package:fantastic_guacamole/state/core/app_providers.dart';
import 'package:fantastic_guacamole/state/providers/account_onboarding_provider.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/auth_session_boundary_provider.dart';
import 'package:fantastic_guacamole/state/providers/daily_decision_intelligence_provider.dart';
import 'package:fantastic_guacamole/state/providers/intelligence_provider.dart';
import 'package:fantastic_guacamole/state/providers/notification_permission_provider.dart';
import 'package:fantastic_guacamole/state/providers/settings_ui_provider.dart';
import 'package:fantastic_guacamole/tutorial/adaptive_guide_overlay.dart';
import 'package:fantastic_guacamole/tutorial/guidance_catalogue.dart';
import 'package:fantastic_guacamole/tutorial/guide_hint_layout.dart';
import 'package:fantastic_guacamole/tutorial/guide_hint_place.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/permissions/notification_permission_test_support.dart';

/// The hints for habits, goals, reminders and notification settings appear
/// once, on the screen they describe, and nowhere else: not on the screen
/// underneath a pushed one, and not above a pushed screen they do not
/// describe.
const String _account = 'screen-hints-user';
const Key _card = Key('guide_hint_card');

String get _prefix =>
    'adaptive_guidance_v3.${AccountStorageScope.authenticated(_account).v2Namespace}';

/// First-run guide finished long ago; Today's own hint already seen.
Map<String, Object> get _existingUser {
  final int at = DateTime.utc(2020).millisecondsSinceEpoch;
  return <String, Object>{
    for (final String milestone in <String>[
      'firstItem',
      'firstSchedule',
      'firstTimelineReview',
    ]) ...<String, Object>{
      '$_prefix.$milestone.at': at,
      '$_prefix.$milestone.count': 1,
    },
    '$_prefix.complete.nexus': true,
  };
}

Future<bool?> _seen(GuidanceLessonId id) async =>
    (await SharedPreferences.getInstance()).getBool(
      '$_prefix.complete.${id.name}',
    );

Finder _cardText(String text) =>
    find.descendant(of: find.byKey(_card), matching: find.text(text));

void main() {
  testWidgets('the Habits hint appears once on the pushed Habits screen, not '
      'on Today under it', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(_existingUser);
    await _pumpApp(tester);
    expect(find.text('Today page'), findsOneWidget);
    expect(find.byKey(_card), findsNothing);

    await tester.tap(find.text('Open habits'));
    await _settle(tester);
    expect(find.text('Habits page'), findsOneWidget);
    expect(_cardText(GuidanceCatalogue.habits.title.en), findsOneWidget);
    expect(await _seen(GuidanceLessonId.habits), isTrue);

    // Back on Today the Habits hint is gone.
    await tester.tap(find.text('Back'));
    await _settle(tester);
    expect(find.text('Today page'), findsOneWidget);
    expect(find.byKey(_card), findsNothing);

    // Seen once: it does not return on the next visit.
    await tester.tap(find.text('Open habits'));
    await _settle(tester);
    expect(find.text('Habits page'), findsOneWidget);
    expect(find.byKey(_card), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Today\'s own hint is not drawn above a screen pushed on top '
      'that it does not describe', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(
      <String, Object>{..._existingUser}..remove('$_prefix.complete.nexus'),
    );
    await _pumpApp(tester);
    expect(
      _cardText(GuidanceCatalogue.nexus.title.en),
      findsOneWidget,
      reason: 'Today shows its own hint',
    );
    await tester.tap(find.text('Open other screen'));
    await _settle(tester);
    expect(find.text('Other page'), findsOneWidget);
    expect(find.byKey(_card), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the Goals hint appears once on Goals and nowhere else', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(_existingUser);
    final GoRouter router = await _pumpApp(tester);
    for (final String route in <String>[
      RoutePaths.settings,
      RoutePaths.creator,
    ]) {
      router.go(route);
      await _settle(tester);
      expect(find.byKey(_card), findsNothing, reason: route);
    }
    router.go(RoutePaths.creatorGoals);
    await _settle(tester);
    expect(_cardText(GuidanceCatalogue.goals.title.en), findsOneWidget);
    expect(await _seen(GuidanceLessonId.goals), isTrue);
    router.go(RoutePaths.nexus);
    await _settle(tester);
    router.go(RoutePaths.creatorGoals);
    await _settle(tester);
    expect(find.byKey(_card), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the notification settings hint appears only while the '
      'Notifications area is open, in Spanish too', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(_existingUser);
    final GoRouter router = await _pumpApp(tester, language: 'es');
    router.go(RoutePaths.settings);
    await _settle(tester);
    expect(find.byKey(_card), findsNothing);

    await tester.tap(find.text('Toggle notifications'));
    await _settle(tester);
    expect(
      _cardText(GuidanceCatalogue.notificationSettings.title.es),
      findsOneWidget,
    );
    expect(
      _cardText(GuidanceCatalogue.notificationSettings.body.es),
      findsOneWidget,
    );
    expect(await _seen(GuidanceLessonId.notificationSettings), isTrue);

    // Closing the area takes the hint with it; it does not come back.
    await tester.tap(find.text('Toggle notifications'));
    await _settle(tester);
    expect(find.byKey(_card), findsNothing);
    await tester.tap(find.text('Toggle notifications'));
    await _settle(tester);
    expect(find.byKey(_card), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('after a reminder is saved while notifications stay off, the '
      'reminders hint appears once on that screen and its action goes to '
      'device settings', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(_existingUser);
    final GoRouter router = await _pumpApp(tester);
    router.go(RoutePaths.creator);
    await _settle(tester);
    expect(find.byKey(_card), findsNothing);

    await tester.tap(find.text('Save with reminder'));
    await _settle(tester);
    expect(_cardText(GuidanceCatalogue.remindersOff.title.en), findsOneWidget);
    expect(await _seen(GuidanceLessonId.remindersOff), isTrue);

    final ProviderContainer container = ProviderScope.containerOf(
      tester.element(find.text('Add page')),
    );
    final FakePermissionActions actions =
        container.read(settingsUiActionsProvider) as FakePermissionActions;
    await tester.tap(find.widgetWithText(TextButton, 'Turn on notifications'));
    await _settle(tester);
    expect(actions.settingsOpened, 1);
    expect(find.byKey(_card), findsNothing);

    // Once per account: a later save does not bring it back.
    await tester.tap(find.text('Save with reminder'));
    await _settle(tester);
    expect(find.byKey(_card), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the reminders hint stays on the screen of the save and is '
      'left to the notice on Today', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(_existingUser);
    final GoRouter router = await _pumpApp(tester);
    // Saved on Today, which shows the notifications-off notice itself.
    await tester.tap(find.text('Save with reminder'));
    await _settle(tester);
    expect(find.byKey(_card), findsNothing);
    // Nothing follows the person to another screen.
    router.go(RoutePaths.creator);
    await _settle(tester);
    expect(find.byKey(_card), findsNothing);
    expect(await _seen(GuidanceLessonId.remindersOff), isNull);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _settle(WidgetTester tester) async {
  for (int i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Widget _saveWithReminder() => Consumer(
  builder: (BuildContext context, WidgetRef ref, _) => TextButton(
    onPressed: () => ref
        .read(remindersOffHintRequestsProvider.notifier)
        .reminderSavedWhileOff(),
    child: const Text('Save with reminder'),
  ),
);

class _TodayPage extends StatelessWidget {
  const _TodayPage();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: ListView(
      children: <Widget>[
        const Text('Today page'),
        TextButton(
          onPressed: () => Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (_) => GuideHintPlace(
                place: GuidancePlaces.habits,
                child: Scaffold(
                  body: ListView(
                    children: <Widget>[
                      const Text('Habits page'),
                      Builder(
                        builder: (BuildContext context) => TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Back'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          child: const Text('Open habits'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (_) =>
                  const Scaffold(body: Center(child: Text('Other page'))),
            ),
          ),
          child: const Text('Open other screen'),
        ),
        _saveWithReminder(),
      ],
    ),
  );
}

class _SettingsPage extends StatefulWidget {
  const _SettingsPage();

  @override
  State<_SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<_SettingsPage> {
  bool _open = false;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: ListView(
      children: <Widget>[
        const Text('Settings page'),
        TextButton(
          onPressed: () => setState(() => _open = !_open),
          child: const Text('Toggle notifications'),
        ),
        if (_open)
          const GuideHintPlace(
            place: GuidancePlaces.notificationSettings,
            child: Text('Notification controls'),
          ),
      ],
    ),
  );
}

Future<GoRouter> _pumpApp(WidgetTester tester, {String language = 'en'}) async {
  final GuideHintModalObserver modals = GuideHintModalObserver();
  final GoRouter router = GoRouter(
    initialLocation: RoutePaths.nexus,
    observers: <NavigatorObserver>[modals],
    routes: <RouteBase>[
      GoRoute(
        path: RoutePaths.nexus,
        builder: (BuildContext context, GoRouterState state) =>
            const _TodayPage(),
      ),
      GoRoute(
        path: RoutePaths.creator,
        builder: (BuildContext context, GoRouterState state) => Scaffold(
          body: ListView(
            children: <Widget>[const Text('Add page'), _saveWithReminder()],
          ),
        ),
      ),
      GoRoute(
        path: RoutePaths.creatorGoals,
        builder: (BuildContext context, GoRouterState state) =>
            const Scaffold(body: Center(child: Text('Goals page'))),
      ),
      GoRoute(
        path: RoutePaths.settings,
        builder: (BuildContext context, GoRouterState state) =>
            const _SettingsPage(),
      ),
    ],
  );
  modals.attachTo(router);
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        accountStorageScopeProvider.overrideWithValue(
          AccountStorageScope.authenticated(_account),
        ),
        domainTaskRepositoryProvider.overrideWithValue(_NoTasks()),
        accountOnboardingCompleteProvider.overrideWith(_SetupDone.new),
        authUserProvider.overrideWith(
          (Ref ref) => Stream<User?>.value(
            const User(
              id: _account,
              email: 'hints@example.test',
              emailVerified: true,
            ),
          ),
        ),
        authSessionBoundaryProvider.overrideWith(_ReadyBoundary.new),
        dailyDecisionIntelligenceProvider.overrideWith((Ref ref) => _decision),
        // This account already refused the system dialog.
        notificationPermissionProvider.overrideWith(_Refused.new),
        settingsUiActionsProvider.overrideWith(
          (Ref ref) => FakePermissionActions(ref, FakePermissionScheduler()),
        ),
      ],
      child: MaterialApp.router(
        locale: Locale(language),
        supportedLocales: ChronoSparkLocalizations.supportedLocales,
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          ChronoSparkLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        routerConfig: router,
        // Mirrors the app root.
        builder: (BuildContext context, Widget? child) => Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Positioned.fill(
              child: GuideHintSpace(child: child ?? const SizedBox.shrink()),
            ),
            ListenableBuilder(
              listenable: router.routerDelegate,
              builder: (BuildContext context, Widget? _) =>
                  AdaptiveGuideOverlay(
                    key: ValueKey<String>(router.routerDelegate.state.uri.path),
                    router: router,
                  ),
            ),
          ],
        ),
      ),
    ),
  );
  await _settle(tester);
  return router;
}

class _Refused extends NotificationPermissionController {
  @override
  NotificationPermissionMemory build() => const NotificationPermissionMemory(
    refusal: NotificationPermissionRefusal.denied,
  );
}

class _SetupDone extends AccountOnboardingCompleteNotifier {
  @override
  bool build() => true;
}

class _ReadyBoundary extends AuthSessionBoundaryNotifier {
  @override
  AuthSessionBoundary build() => const AuthSessionBoundary(
    generation: 1,
    userId: _account,
    isTransitioning: false,
    isStorageReady: true,
  );
}

class _NoTasks implements ITaskRepository {
  @override
  Future<List<TaskEntity>> getAllTasks() async => <TaskEntity>[];
  @override
  Future<TaskEntity?> getTaskById(String id) async => null;
  @override
  Future<void> saveTask(TaskEntity task) async {}
  @override
  Future<void> deleteTask(String id) async {}
}

const DailyDecisionIntelligence _decision = DailyDecisionIntelligence(
  primaryAction: 'Work on Task A',
  momentum: '60% steady',
  trajectory: 'Stable',
  energy: '70% energy',
  warning: 'No material constraint is supported by the current evidence.',
  recovery: 'Protect a short recovery window.',
  recommendedAction: 'Work on Task A',
  rationale: 'Task A is the highest feasible item.',
  changeSummary: 'Task A moved up.',
  evidence: <String>['priority=5'],
  confidence: .7,
  observedOutcomes: 1,
);
