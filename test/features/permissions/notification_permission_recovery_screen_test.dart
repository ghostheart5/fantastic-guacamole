import 'package:fantastic_guacamole/features/permissions/notification_permission_recovery_screen.dart';
import 'package:fantastic_guacamole/state/providers/settings_ui_provider.dart';
import 'package:fantastic_guacamole/state/services/reflection_reminder_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('notification recovery screen renders action buttons', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: NotificationPermissionRecoveryScreen(),
        ),
      ),
    );

    expect(find.text('Notification Recovery'), findsOneWidget);
    expect(find.text('Request Permission Again'), findsOneWidget);
    expect(find.text('Open System App Settings'), findsOneWidget);
  });

  testWidgets('hides retry action when permission is permanently denied', (
    WidgetTester tester,
  ) async {
    final ValueNotifier<NotificationPermissionState> permissionStateListenable =
        ValueNotifier<NotificationPermissionState>(
          NotificationPermissionState.permanentlyDenied,
        );
    addTearDown(permissionStateListenable.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationPermissionStateListenableProvider.overrideWithValue(
            permissionStateListenable,
          ),
        ],
        child: const MaterialApp(
          home: NotificationPermissionRecoveryScreen(),
        ),
      ),
    );

    expect(find.text('Request Permission Again'), findsNothing);
    expect(
      find.text(
        'Permission is permanently denied. Open system settings to re-enable notifications.',
      ),
      findsOneWidget,
    );
  });
}
