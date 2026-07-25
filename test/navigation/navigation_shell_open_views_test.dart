import 'package:fantastic_guacamole/app/navigation_shell.dart';
import 'package:fantastic_guacamole/state/controllers/app_flow_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Future<ProviderContainer> pumpNavigationShell(WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: NavigationShell(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final BuildContext context = tester.element(find.byType(NavigationShell));
    return ProviderScope.containerOf(context);
  }

  group('NavigationShell open-view smoke tests', () {
    testWidgets('all release-critical views open without Flutter exceptions', (
      WidgetTester tester,
    ) async {
      final ProviderContainer container = await pumpNavigationShell(tester);

      expect(container.read(appFlowProvider), AppView.nexus);
      expect(tester.takeException(), isNull);

      final List<AppView> views = <AppView>[
        AppView.nexus,
        AppView.tasks,
        AppView.logs,
        AppView.profile,
        AppView.smartCoach,
        AppView.goals,
        AppView.timeline,
        AppView.memories,
        AppView.milestones,
        AppView.flowmap,
        AppView.soulMap,
        AppView.settings,
        AppView.progression,
        AppView.plan,
        AppView.insight,
        AppView.console,
        AppView.creator,
      ];

      for (final AppView view in views) {
        container.read(appFlowProvider.notifier).show(view);

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(
          container.read(appFlowProvider),
          view,
          reason: 'NavigationShell should switch to $view.',
        );

        expect(
          tester.takeException(),
          isNull,
          reason: '$view should render without unhandled Flutter exceptions.',
        );
      }
    });

    testWidgets('tab views can cycle repeatedly without state corruption', (
      WidgetTester tester,
    ) async {
      final ProviderContainer container = await pumpNavigationShell(tester);

      final List<AppView> tabViews = <AppView>[
        AppView.nexus,
        AppView.tasks,
        AppView.logs,
        AppView.profile,
      ];

      for (int cycle = 0; cycle < 3; cycle++) {
        for (final AppView view in tabViews) {
          container.read(appFlowProvider.notifier).show(view);

          await tester.pump();
          await tester.pump(const Duration(milliseconds: 80));

          expect(container.read(appFlowProvider), view);
          expect(tester.takeException(), isNull);
        }
      }

      container.read(appFlowProvider.notifier).toNexus();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));

      expect(container.read(appFlowProvider), AppView.nexus);
      expect(tester.takeException(), isNull);
    });
  });
}
