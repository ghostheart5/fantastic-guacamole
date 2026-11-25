import 'package:fantastic_guacamole/features/permissions/notification_permission_notice.dart';
import 'package:fantastic_guacamole/state/services/reminder_orchestrator_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'notification_permission_test_support.dart';

const _allOff = ReminderOrchestratorPrefs(
  goalRemindersEnabled: false,
  habitRemindersEnabled: false,
  dailyPlanningEnabled: false,
  dailyPlanningHour: 7,
  dailyPlanningMinute: 30,
);

const _englishMessage =
    'Reminders are on, but notifications are off for Axiomara.';
const _spanishMessage =
    'Los recordatorios están activados, pero las notificaciones de Axiomara están desactivadas.';

void main() {
  const Widget screen = Scaffold(body: NotificationPermissionNotice());

  testWidgets('shows only when a reminder switch is on and permission is off', (
    tester,
  ) async {
    final fixture = PermissionFixture();
    await tester.pumpWidget(fixture.app(screen));

    // Permission not read yet.
    expect(find.text(_englishMessage), findsNothing);

    fixture.scheduler.signal.value = false;
    await tester.pump();
    expect(find.text(_englishMessage), findsOneWidget);

    fixture.scheduler.signal.value = true;
    await tester.pump();
    expect(find.text(_englishMessage), findsNothing);

    fixture.scheduler.signal.value = false;
    fixture.actions.reminderPrefs = _allOff;
    await tester.pumpWidget(fixture.app(const Scaffold(body: Text('away'))));
    await tester.pumpWidget(fixture.app(screen));
    expect(find.text(_englishMessage), findsNothing);

    fixture.actions.reflectionEnabled = true;
    await tester.pumpWidget(fixture.app(const Scaffold(body: Text('away'))));
    await tester.pumpWidget(fixture.app(screen));
    expect(find.text(_englishMessage), findsOneWidget);
  });

  for (final spanish in <bool>[false, true]) {
    testWidgets(
      'notice is ${spanish ? 'Spanish' : 'English'} and dismissible',
      (tester) async {
        final fixture = PermissionFixture();
        fixture.scheduler.signal.value = false;
        await tester.pumpWidget(fixture.app(screen, spanish: spanish));

        expect(
          find.text(spanish ? _spanishMessage : _englishMessage),
          findsOneWidget,
        );
        expect(
          find.text(
            spanish ? 'Activar notificaciones' : 'Turn on notifications',
          ),
          findsOneWidget,
        );

        await tester.tap(find.byTooltip(spanish ? 'Descartar' : 'Dismiss'));
        await tester.pumpAndSettle();
        expect(
          find.text(spanish ? _spanishMessage : _englishMessage),
          findsNothing,
        );

        // Still dismissed when the screen is opened again.
        await tester.pumpWidget(
          fixture.app(const Scaffold(body: Text('away'))),
        );
        await tester.pumpWidget(fixture.app(screen, spanish: spanish));
        expect(
          find.text(spanish ? _spanishMessage : _englishMessage),
          findsNothing,
        );
      },
    );
  }

  testWidgets('its action runs the permission helper', (tester) async {
    final fixture = PermissionFixture();
    fixture.scheduler.signal.value = false;
    fixture.actions.grantOnRequest = true;
    await tester.pumpWidget(fixture.app(screen));

    await tester.tap(find.text('Turn on notifications'));
    await tester.pumpAndSettle();
    expect(find.text('WHEN IT IS USED'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Allow Notifications'));
    await tester.pumpAndSettle();

    expect(fixture.actions.requests, 1);
    expect(fixture.actions.refreshes, 1);
    expect(find.text(_englishMessage), findsNothing);
  });

  testWidgets('after a system refusal its action opens device settings', (
    tester,
  ) async {
    final fixture = PermissionFixture();
    fixture.scheduler.signal.value = false;
    await tester.pumpWidget(fixture.app(screen));

    await tester.tap(find.text('Turn on notifications'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Allow Notifications'));
    await tester.pumpAndSettle();
    expect(fixture.actions.requests, 1);
    expect(fixture.actions.settingsOpened, 0);

    // The system may no longer show its dialog: go to device settings.
    await tester.tap(find.text('Turn on notifications'));
    await tester.pumpAndSettle();
    expect(find.text('WHEN IT IS USED'), findsNothing);
    expect(fixture.actions.requests, 1);
    expect(fixture.actions.settingsOpened, 1);
  });
}
