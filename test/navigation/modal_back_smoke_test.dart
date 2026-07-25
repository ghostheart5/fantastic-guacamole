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
    await tester.pump(const Duration(milliseconds: 150));

    final BuildContext context = tester.element(find.byType(NavigationShell));
    return ProviderScope.containerOf(context);
  }

  Future<void> openView(
    WidgetTester tester,
    ProviderContainer container,
    AppView view,
  ) async {
    container.read(appFlowProvider.notifier).show(view);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    expect(container.read(appFlowProvider), view);
    expect(tester.takeException(), isNull);
  }

  Future<void> expectModalClosesWithBack({
    required WidgetTester tester,
    required ProviderContainer container,
    required AppView expectedView,
  }) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.byType(BottomSheet), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.byType(BottomSheet), findsNothing);
    expect(container.read(appFlowProvider), expectedView);
    expect(tester.takeException(), isNull);
  }

  group('NavigationShell modal back smoke tests', () {
    testWidgets('Goals add sheet closes with back and keeps Goals active', (
      WidgetTester tester,
    ) async {
      final ProviderContainer container = await pumpNavigationShell(tester);

      await openView(tester, container, AppView.goals);

      await tester.tap(find.byIcon(Icons.add).first);
      await expectModalClosesWithBack(
        tester: tester,
        container: container,
        expectedView: AppView.goals,
      );
    });

    testWidgets('Milestones create sheet closes with back and keeps Milestones active', (
      WidgetTester tester,
    ) async {
      final ProviderContainer container = await pumpNavigationShell(tester);

      await openView(tester, container, AppView.milestones);

      await tester.tap(find.text('NEW MILESTONE'));
      await expectModalClosesWithBack(
        tester: tester,
        container: container,
        expectedView: AppView.milestones,
      );
    });

    testWidgets('Memories create sheet closes with back and keeps Memories active', (
      WidgetTester tester,
    ) async {
      final ProviderContainer container = await pumpNavigationShell(tester);

      await openView(tester, container, AppView.memories);

      await tester.tap(find.text('NEW MEMORY'));
      await expectModalClosesWithBack(
        tester: tester,
        container: container,
        expectedView: AppView.memories,
      );
    });

    testWidgets('FlowMap add sheet closes with back and keeps FlowMap active', (
      WidgetTester tester,
    ) async {
      final ProviderContainer container = await pumpNavigationShell(tester);

      await openView(tester, container, AppView.flowmap);

      await tester.tap(find.byIcon(Icons.account_tree_outlined));
      await expectModalClosesWithBack(
        tester: tester,
        container: container,
        expectedView: AppView.flowmap,
      );
    });
  });
}
