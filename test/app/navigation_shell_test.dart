import 'package:fantastic_guacamole/app/navigation_shell.dart';
import 'package:fantastic_guacamole/core/network/network_status_service.dart';
import 'package:fantastic_guacamole/features/si_console/ui/si_console_screen.dart';
import 'package:fantastic_guacamole/state/controllers/app_flow_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('console route is available with the free AI credit allowance', (
    WidgetTester tester,
  ) async {
    _setLargeTestSurface(tester);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appFlowProvider.overrideWith(
            () => _FixedFlowController(AppView.console),
          ),
          isOnlineProvider.overrideWithValue(true),
        ],
        child: const MaterialApp(
          home: NavigationShell(initialView: AppView.console),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(SIConsoleScreen), findsOneWidget);
  });

  testWidgets('offline banner appears when connection is offline', (
    WidgetTester tester,
  ) async {
    _setLargeTestSurface(tester);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appFlowProvider.overrideWith(
            () => _FixedFlowController(AppView.console),
          ),
          isOnlineProvider.overrideWithValue(false),
        ],
        child: const MaterialApp(
          home: NavigationShell(initialView: AppView.console),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Offline Mode — actions will sync later'), findsOneWidget);
  });
}

class _FixedFlowController extends AppFlowController {
  _FixedFlowController(this._initial);

  final AppView _initial;

  @override
  AppView build() => _initial;
}

void _setLargeTestSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 2560);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
