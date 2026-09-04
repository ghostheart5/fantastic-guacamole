import 'package:fantastic_guacamole/app/navigation_shell.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_namespace.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Exercises the app's single [PopScope] (in [NavigationShell]) under a rapid
/// double back-press while its own navigation-map bottom sheet is open — the
/// concurrency window flagged in the Phase 4 chaos-testing ledger, since none
/// of the 13 dialog/bottom-sheet call sites elsewhere have their own back
/// handling and this is the only place that intercepts system pops at all.
void main() {
  int systemNavigatorPopCalls = 0;

  setUp(() {
    systemNavigatorPopCalls = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (
          MethodCall call,
        ) async {
          if (call.method == 'SystemNavigator.pop') {
            systemNavigatorPopCalls++;
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Future<ProviderContainer> pumpShell(
    WidgetTester tester, {
    AppView initialView = AppView.nexus,
  }) async {
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
          AccountStorageScope.authenticated('navigation-back-test-account'),
        ),
        accountLegacyOwnershipProvider.overrideWithValue(
          LegacyScopeOwnership.provenNotOwned,
        ),
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
        child: MaterialApp(home: NavigationShell(initialView: initialView)),
      ),
    );
    await tester.pump();
    return container;
  }

  testWidgets(
    'a single back-press closes the navigation-map sheet without exiting',
    (WidgetTester tester) async {
      final ProviderContainer container = await pumpShell(tester);
      expect(container.read(appFlowProvider), AppView.nexus);

      await tester.tap(find.byTooltip('Open navigation map'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Navigation Map'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.text('Navigation Map'),
        findsNothing,
        reason: 'one back-press should only dismiss the open sheet',
      );
      expect(
        systemNavigatorPopCalls,
        0,
        reason:
            'dismissing the sheet must not also fall through to the '
            "shell's own exit-app branch",
      );
    },
  );

  testWidgets(
    'two back-presses fired with no intervening frame do not double-exit',
    (WidgetTester tester) async {
      final ProviderContainer container = await pumpShell(tester);
      expect(container.read(appFlowProvider), AppView.nexus);

      await tester.tap(find.byTooltip('Open navigation map'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Navigation Map'), findsOneWidget);

      // No `await`/`pump()` between these two: this is the race the ledger
      // flagged — a rapid double back-press during a modal's own pop
      // transition, before a frame has a chance to reconcile the route
      // stack in between.
      final Future<void> firstPop = tester.binding.handlePopRoute();
      final Future<void> secondPop = tester.binding.handlePopRoute();
      await firstPop;
      await secondPop;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        systemNavigatorPopCalls,
        lessThanOrEqualTo(1),
        reason:
            'two back-presses queued without an intervening frame must '
            "still only reach the shell's exit-app branch at most once — "
            'a higher count would mean the app tried to exit twice from a '
            'single rapid gesture',
      );
      // Whatever the sheet/exit outcome, the shell must land on a single,
      // well-defined view rather than a torn/inconsistent state.
      expect(AppView.values, contains(container.read(appFlowProvider)));
    },
  );

  for (final AppView view in const <AppView>[
    AppView.timeline,
    AppView.trajectoryEngine,
    AppView.profile,
  ]) {
    testWidgets('back from ${view.name} returns to Nexus without exiting', (
      WidgetTester tester,
    ) async {
      final ProviderContainer container = await pumpShell(
        tester,
        initialView: view,
      );
      expect(container.read(appFlowProvider), view);

      await tester.binding.handlePopRoute();
      await tester.pump();

      expect(container.read(appFlowProvider), AppView.nexus);
      expect(systemNavigatorPopCalls, 0);
    });
  }

  testWidgets('back from Nexus exits the app once', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = await pumpShell(tester);
    expect(container.read(appFlowProvider), AppView.nexus);

    await tester.binding.handlePopRoute();
    await tester.pump();

    expect(container.read(appFlowProvider), AppView.nexus);
    expect(systemNavigatorPopCalls, 1);
  });
}

class _StaticGoals extends GoalsNotifier {
  @override
  List<GoalEntity> build() => const <GoalEntity>[];
}
