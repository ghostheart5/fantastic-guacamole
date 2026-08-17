import 'package:fantastic_guacamole/app/navigation_shell.dart';
import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/system/notifications/notification_scheduler.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tapping a notification has to land the user on the surface the notification
/// was about. The routing existed but was never covered, so a payload prefix
/// could be renamed at the producing end and silently start falling through to
/// the default surface with nothing failing.
void main() {
  setUp(() => NotificationScheduler.tappedPayloadListenable.value = null);
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
        unreadNotificationsProvider.overrideWithValue(0),
        // GoalsNotifier.build schedules a timer that outlives the test frame,
        // and routing to goals mounts it.
        goalsProvider.overrideWith(_StaticGoals.new),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: NavigationShell()),
      ),
    );
    await tester.pump();
    return container;
  }

  // These are the ids the producers actually emit, not invented prefixes:
  // reminder_orchestrator_service, reflection_reminder_service and
  // profile_controller respectively. Testing the real values is the point —
  // a router prefix that no producer emits would pass a synthetic test while
  // every real tap fell through to the default surface.
  for (final (String payload, AppView expected) in <(String, AppView)>[
    ('goal_reminder_abc123', AppView.goals),
    ('daily_planning_reminder', AppView.plan),
    ('habit_reminder_daily', AppView.tasks),
    ('reflection_reminder', AppView.logs),
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

  testWidgets('an unrecognised payload falls back rather than being dropped', (
    WidgetTester tester,
  ) async {
    // A tap must always take the user somewhere. Silently ignoring an unknown
    // id would leave them on whatever tab happened to be open, which reads as
    // the notification doing nothing.
    final ProviderContainer container = await pumpShell(tester);

    NotificationScheduler.tappedPayloadListenable.value = 'something_unmapped';
    await tester.pump();

    expect(container.read(appFlowProvider), AppView.logs);
  });

  testWidgets('the payload is cleared so one tap does not route twice', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = await pumpShell(tester);

    NotificationScheduler.tappedPayloadListenable.value =
        'habit_reminder_daily';
    await tester.pump();
    expect(container.read(appFlowProvider), AppView.tasks);
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
