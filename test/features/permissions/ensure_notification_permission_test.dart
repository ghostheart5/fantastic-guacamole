import 'package:fantastic_guacamole/features/permissions/notification_permission_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'notification_permission_test_support.dart';

void main() {
  final List<bool> results = <bool>[];

  Widget trigger({bool userInitiated = false}) => Scaffold(
    body: Consumer(
      builder: (context, ref, _) => TextButton(
        onPressed: () async => results.add(
          await ensureNotificationPermission(
            context,
            ref,
            userInitiated: userInitiated,
          ),
        ),
        child: const Text('Save something'),
      ),
    ),
  );

  setUp(results.clear);

  testWidgets('explains first, asks the system once, never again after no', (
    tester,
  ) async {
    final fixture = PermissionFixture();
    await tester.pumpWidget(fixture.app(trigger()));

    await tester.tap(find.text('Save something'));
    await tester.pumpAndSettle();
    expect(find.text('WHEN IT IS USED'), findsOneWidget);
    expect(fixture.actions.requests, 0, reason: 'Explanation comes first.');

    await tester.tap(find.widgetWithText(FilledButton, 'Allow Notifications'));
    await tester.pumpAndSettle();
    expect(fixture.actions.requests, 1);
    expect(results, <bool>[false]);
    expect(fixture.actions.refreshes, 0);

    await tester.tap(find.text('Save something'));
    await tester.pumpAndSettle();
    expect(find.text('WHEN IT IS USED'), findsNothing);
    expect(fixture.actions.requests, 1, reason: 'A refusal is remembered.');
    expect(results, <bool>[false, false]);
  });

  testWidgets('"Not now" is remembered for this account only', (tester) async {
    final fixture = PermissionFixture();
    await tester.pumpWidget(fixture.app(trigger()));

    await tester.tap(find.text('Save something'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Not Now'));
    await tester.pumpAndSettle();
    expect(fixture.actions.requests, 0);
    expect(results, <bool>[false]);

    await tester.tap(find.text('Save something'));
    await tester.pumpAndSettle();
    expect(find.text('WHEN IT IS USED'), findsNothing);

    fixture.selectAccount('b');
    await tester.pump();
    await tester.tap(find.text('Save something'));
    await tester.pumpAndSettle();
    expect(
      find.text('WHEN IT IS USED'),
      findsOneWidget,
      reason: 'Another account has not refused yet.',
    );
  });

  testWidgets('never asks when notifications are already allowed', (
    tester,
  ) async {
    final fixture = PermissionFixture();
    fixture.scheduler.granted = true;
    await tester.pumpWidget(fixture.app(trigger()));

    await tester.tap(find.text('Save something'));
    await tester.pumpAndSettle();

    expect(find.text('WHEN IT IS USED'), findsNothing);
    expect(fixture.actions.requests, 0);
    expect(results, <bool>[true]);
  });

  testWidgets('a grant rebuilds reminders through the existing reconcile', (
    tester,
  ) async {
    final fixture = PermissionFixture();
    fixture.actions.grantOnRequest = true;
    await tester.pumpWidget(fixture.app(trigger()));

    await tester.tap(find.text('Save something'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Allow Notifications'));
    await tester.pumpAndSettle();

    expect(results, <bool>[true]);
    expect(fixture.actions.refreshes, 1);
  });

  testWidgets('an explicit request still asks after a refusal', (tester) async {
    final fixture = PermissionFixture();
    await tester.pumpWidget(fixture.app(trigger()));
    await tester.tap(find.text('Save something'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Not Now'));
    await tester.pumpAndSettle();

    await tester.pumpWidget(fixture.app(trigger(userInitiated: true)));
    await tester.tap(find.text('Save something'));
    await tester.pumpAndSettle();
    expect(find.text('WHEN IT IS USED'), findsOneWidget);
  });
}
