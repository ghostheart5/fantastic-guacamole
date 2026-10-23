import 'dart:async';
import 'package:fantastic_guacamole/state/providers/settings_ui_provider.dart';
import 'dart:convert';
import 'package:fantastic_guacamole/app/router/route_guards.dart' as guards;
import 'package:fantastic_guacamole/state/providers/auth_provider.dart'
    show passwordRecoveryStateProvider;
import 'package:fantastic_guacamole/data/services/contracts/password_recovery_auth.dart';

import 'package:fantastic_guacamole/app/navigation_shell.dart';
import 'package:fantastic_guacamole/core/data/account_data_registry.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_namespace.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task.dart';
import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/features/creator/ui/record_library_screen.dart';
import 'package:fantastic_guacamole/features/timeline/ui/timeline_screen.dart';
import 'package:fantastic_guacamole/state/providers/timeline_provider.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/system/notifications/notification_scheduler.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tapping a notification has to land the user on the surface the notification
/// was about. The routing existed but was never covered, so a payload prefix
/// could be renamed at the producing end and silently start falling through to
/// the default surface with nothing failing.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  AndroidFlutterLocalNotificationsPlugin.registerWith();
  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  String? launchPayload;
  setUp(() async {
    NotificationScheduler.tappedPayloadListenable.value = null;
    launchPayload = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'initialize' ||
              call.method == 'areNotificationsEnabled') {
            return true;
          }
          if (call.method == 'getNotificationAppLaunchDetails') {
            final payload = launchPayload;
            return <String, Object?>{
              'notificationLaunchedApp': payload != null,
              if (payload != null)
                'notificationResponse': <String, Object?>{
                  'notificationResponseType': 0,
                  'payload': payload,
                },
            };
          }
          if (call.method == 'pendingNotificationRequests') return <Object>[];
          return null;
        });
    NotificationScheduler().resetLaunchConsumptionForTesting();
    await NotificationScheduler().init(requestPermissions: false);
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );
  tearDown(() => NotificationScheduler.tappedPayloadListenable.value = null);

  Future<ProviderContainer> pumpShell(WidgetTester tester) async {
    tester.platformDispatcher.views.first
      ..physicalSize = const Size(1200, 2400)
      ..devicePixelRatio = 1.0;
    addTearDown(() {
      tester.platformDispatcher.views.first
        ..resetPhysicalSize()
        ..resetDevicePixelRatio();
    });

    final ProviderContainer container = ProviderContainer(
      overrides: [
        accountStorageScopeProvider.overrideWithValue(
          AccountStorageScope.authenticated(
            'notification-routing-test-account',
          ),
        ),
        accountLegacyOwnershipProvider.overrideWithValue(
          LegacyScopeOwnership.provenNotOwned,
        ),
        unreadNotificationsProvider.overrideWithValue(0),
        guards.authenticatedGuardProvider.overrideWithValue(true),
        guards.onboardingWelcomeCompleteGuardProvider.overrideWithValue(true),
        guards.onboardingCompleteGuardProvider.overrideWithValue(true),
        passwordRecoveryStateProvider.overrideWithValue(
          const AsyncData(PasswordRecoveryState.inactive()),
        ),
        // GoalsNotifier.build schedules a timer that outlives the test frame,
        // and routing to goals mounts it.
        settingsUiActionsProvider.overrideWith(_RoutingSettingsActions.new),
        goalsProvider.overrideWith(_StaticGoals.new),
        timelineProvider.overrideWith(_StaticTimeline.new),
        timelinePersistenceCorruptedProvider.overrideWithValue(false),
        allTasksProvider.overrideWith((ref) async => const <Task>[]),
      ],
    );
    final boundary = container.read(authSessionBoundaryProvider.notifier);
    final generation = boundary.begin(
      userId: 'notification-routing-test-account',
      isTransitioning: true,
    );
    boundary.complete(generation);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: NavigationShell()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
    return container;
  }

  // These are the ids the producers actually emit, not invented prefixes:
  // reminder_orchestrator_service, reflection_reminder_service and
  // profile_controller respectively. Testing the real values is the point —
  // a router prefix that no producer emits would pass a synthetic test while
  // every real tap fell through to the default surface.
  for (final (String payload, AppView expected) in <(String, AppView)>[
    ('goal_reminder_abc123', AppView.goals),
    ('daily_planning_reminder', AppView.smartPlanner),
    ('habit_reminder_daily', AppView.creator),
    ('streak_break_recovery_xyz', AppView.progression),
  ]) {
    testWidgets('tapping "$payload" routes to $expected', (
      WidgetTester tester,
    ) async {
      final ProviderContainer container = await pumpShell(tester);

      NotificationScheduler.tappedPayloadListenable.value = payload;
      await tester.pump();

      expect(container.read(appFlowProvider), expected);
    });
  }

  String reflectionPayload(String account) => jsonEncode(<String, Object>{
    'v': 1,
    'accountScope': AccountDataRegistry.accountDigest(account),
    'notificationId': 'reflection_reminder',
  });

  for (final cold in <bool>[false, true]) {
    testWidgets(
      '${cold ? 'cold launch' : 'foreground tap'} reflection opens actual Schedule once',
      (tester) async {
        final payload = reflectionPayload('notification-routing-test-account');
        if (cold) launchPayload = payload;
        final container = await pumpShell(tester);
        if (!cold) {
          NotificationScheduler.tappedPayloadListenable.value = payload;
        }
        await tester.pump(const Duration(seconds: 1));
        await tester.pump();
        expect(find.byType(TimelineScreen), findsOneWidget);
        expect(find.text('Schedule'), findsOneWidget);
        expect(find.byType(RecordLibraryScreen), findsNothing);
        expect(NotificationScheduler.tappedPayloadListenable.value, isNull);
        // A cold plugin response may push during the previous pump's async tail.
        // Advance that route's forward transition before exercising its Back.
        await tester.pump(const Duration(milliseconds: 500));
        final route = ModalRoute.of(
          tester.element(find.byType(TimelineScreen)),
        )!;
        expect(route.animation!.status, AnimationStatus.completed);
        expect(route.isCurrent, isTrue);
        bool popped = false;
        bool transitionCompleted = false;
        unawaited(
          route.popped.then((_) {
            popped = true;
          }),
        );
        unawaited(
          route.completed.then((_) {
            transitionCompleted = true;
          }),
        );
        await tester.tap(find.byTooltip('Back').hitTestable());
        // Start the reverse animation before advancing its fake clock.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump();
        expect(popped, isTrue);
        expect(transitionCompleted, isTrue);
        expect(find.byType(TimelineScreen), findsNothing);
        expect(container.read(appFlowProvider), AppView.nexus);
        await tester.pump(const Duration(seconds: 1));
        expect(find.byType(TimelineScreen), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '${cold ? 'cold launch' : 'foreground tap'} rejects another account reflection',
      (tester) async {
        final payload = reflectionPayload('another-account');
        if (cold) launchPayload = payload;
        final container = await pumpShell(tester);
        if (!cold) {
          NotificationScheduler.tappedPayloadListenable.value = payload;
        }
        await tester.pump(const Duration(seconds: 1));
        await tester.pump();
        expect(find.byType(TimelineScreen), findsNothing);
        expect(container.read(appFlowProvider), AppView.nexus);
        expect(NotificationScheduler.tappedPayloadListenable.value, isNull);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('an unrecognised payload falls back rather than being dropped', (
    WidgetTester tester,
  ) async {
    // A tap must always take the user somewhere. Silently ignoring an unknown
    // id would leave them on whatever tab happened to be open, which reads as
    // the notification doing nothing.
    final ProviderContainer container = await pumpShell(tester);

    NotificationScheduler.tappedPayloadListenable.value = 'something_unmapped';
    await tester.pump();

    expect(container.read(appFlowProvider), AppView.timeline);
  });

  testWidgets('the payload is cleared so one tap does not route twice', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = await pumpShell(tester);

    NotificationScheduler.tappedPayloadListenable.value =
        'habit_reminder_daily';
    await tester.pump();
    expect(container.read(appFlowProvider), AppView.creator);
    expect(NotificationScheduler.tappedPayloadListenable.value, isNull);

    // Navigating away must stick: a stale payload should not drag the user
    // back the next time anything rebuilds.
    container.read(appFlowProvider.notifier).toNexus();
    await tester.pump();

    expect(container.read(appFlowProvider), AppView.nexus);
  });
}

class _StaticGoals extends GoalsNotifier {
  @override
  List<GoalEntity> build() => const <GoalEntity>[];
}

class _StaticTimeline extends TimelineNotifier {
  @override
  List<TimelineEventEntity> build() => const <TimelineEventEntity>[];
}

// Reminder recovery has its own integration suite. Navigation retains the real
// shell dispatch while isolating unrelated reminder repositories/platform I/O.
class _RoutingSettingsActions extends SettingsUiActions {
  _RoutingSettingsActions(super.ref);
  @override
  Future<void> refreshNotificationPermissionAndReminders() async {}
}
