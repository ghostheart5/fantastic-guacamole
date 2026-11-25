import 'package:fantastic_guacamole/features/permissions/notification_permission_flow.dart';
import 'package:fantastic_guacamole/state/providers/reminders_off_hint_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'notification_permission_test_support.dart';

void main() {
  final List<bool> results = <bool>[];

  Widget trigger({bool userInitiated = false, bool afterSave = false}) =>
      Scaffold(
        body: Consumer(
          builder: (context, ref, _) => TextButton(
            onPressed: () async => results.add(
              await ensureNotificationPermission(
                context,
                ref,
                userInitiated: userInitiated,
                afterSave: afterSave,
              ),
            ),
            child: const Text('Save something'),
          ),
        ),
      );

  setUp(results.clear);

  for (final platform in <TargetPlatform>[
    TargetPlatform.windows,
    TargetPlatform.linux,
  ]) {
    testWidgets('${platform.name} has no permission to ask for', (
      tester,
    ) async {
      // The scheduler registers no Windows or Linux settings, so its
      // initialisation (and so any request) has never worked there.
      debugDefaultTargetPlatformOverride = platform;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final fixture = PermissionFixture();
      await tester.pumpWidget(fixture.app(trigger(userInitiated: true)));

      await tester.tap(find.text('Save something'));
      await tester.pumpAndSettle();

      expect(find.text('WHEN IT IS USED'), findsNothing);
      expect(fixture.actions.requests, 0);
      expect(fixture.scheduler.queries, 0);
      expect(results, <bool>[false]);
      debugDefaultTargetPlatformOverride = null;
    });
  }

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

  testWidgets('a reminder saved after a refusal asks the guide to say where '
      'to turn notifications on, without asking again', (tester) async {
    final fixture = PermissionFixture();
    int requests() => fixture.container.read(remindersOffHintRequestsProvider);
    await tester.pumpWidget(fixture.app(trigger(afterSave: true)));

    // The first save asks in context; saying no is not yet a reason.
    await tester.tap(find.text('Save something'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Not Now'));
    await tester.pumpAndSettle();
    expect(requests(), 0);

    // The next save does not ask again; the guide says it once instead.
    await tester.tap(find.text('Save something'));
    await tester.pumpAndSettle();
    expect(find.text('WHEN IT IS USED'), findsNothing);
    expect(requests(), 1);

    // A switch turned on in Settings is not a saved reminder.
    await tester.pumpWidget(fixture.app(trigger()));
    await tester.tap(find.text('Save something'));
    await tester.pumpAndSettle();
    expect(requests(), 1);
  });
}
