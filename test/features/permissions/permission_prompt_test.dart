import 'package:fantastic_guacamole/features/permissions/notification_permission_prompt.dart';
import 'package:fantastic_guacamole/features/permissions/voice_permission_prompt.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('notification prompt explains permission before requesting it', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NotificationPermissionPrompt(
            permissionGranted: null,
            onRequestPermission: () async => true,
            onOpenSystemSettings: () async {},
          ),
        ),
      ),
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Enable Notifications'));
    await tester.pump();

    expect(find.text('Enable Notifications'), findsWidgets);
    expect(find.textContaining('Used only for reminders'), findsOneWidget);
  });

  testWidgets('voice prompt keeps denied recovery visible', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VoicePermissionPrompt(
            permissionGranted: false,
            onRequestPermission: () async => false,
            onOpenSystemSettings: () async {},
          ),
        ),
      ),
    );

    expect(find.text('Voice Access'), findsOneWidget);
    expect(find.text('Microphone Permission Denied'), findsOneWidget);
  });

  testWidgets('voice rationale appears before requesting microphone access', (
    WidgetTester tester,
  ) async {
    int requests = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VoicePermissionPrompt(
            permissionGranted: null,
            onRequestPermission: () async {
              requests += 1;
              return true;
            },
            onOpenSystemSettings: () async {},
          ),
        ),
      ),
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Enable Voice Access'));
    await tester.pumpAndSettle();

    expect(requests, 0);
    expect(find.text('WHEN IT IS USED'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Allow Microphone'));
    await tester.pumpAndSettle();

    expect(requests, 1);
  });
}
