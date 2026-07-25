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

  group('NavigationShell back-button smoke tests', () {
    testWidgets('Smart Coach back returns to Nexus without exception', (
      WidgetTester tester,
    ) async {
      final ProviderContainer container = await pumpNavigationShell(tester);

      expect(container.read(appFlowProvider), AppView.nexus);
      expect(tester.takeException(), isNull);

      container.read(appFlowProvider.notifier).toSmartCoach();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(container.read(appFlowProvider), AppView.smartCoach);
      expect(tester.takeException(), isNull);

      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(container.read(appFlowProvider), AppView.nexus);
      expect(tester.takeException(), isNull);
    });

    testWidgets('secondary views back to Nexus safely', (
      WidgetTester tester,
    ) async {
      final ProviderContainer container = await pumpNavigationShell(tester);

      final List<AppView> views = <AppView>[
        AppView.goals,
        AppView.timeline,
        AppView.memories,
        AppView.milestones,
        AppView.flowmap,
        AppView.soulMap,
        AppView.settings,
      ];

      for (final AppView view in views) {
        container.read(appFlowProvider.notifier).show(view);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(container.read(appFlowProvider), view);
        expect(tester.takeException(), isNull);

        await tester.binding.handlePopRoute();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(container.read(appFlowProvider), AppView.nexus);
        expect(tester.takeException(), isNull);
      }
    });
  });
}
