import 'package:fantastic_guacamole/features/permissions/notification_permission_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'notification_permission_test_support.dart';

void main() {
  testWidgets('the Settings card asks only for local notification permission', (
    tester,
  ) async {
    final fixture = PermissionFixture();
    fixture.actions.grantOnRequest = true;
    await tester.pumpWidget(
      fixture.app(const Scaffold(body: NotificationPermissionSettingsCard())),
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Enable Notifications'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Allow Notifications'));
    await tester.pumpAndSettle();

    expect(fixture.actions.requests, 1);
    expect(fixture.actions.refreshes, 1, reason: 'Reminders are rebuilt.');
  });
}
