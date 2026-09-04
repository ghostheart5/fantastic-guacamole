import 'package:fantastic_guacamole/features/permissions/notification_permission_prompt.dart';
import 'package:fantastic_guacamole/features/permissions/permission_explainer.dart';
import 'package:fantastic_guacamole/features/permissions/permission_rationale_sheet.dart';
import 'package:fantastic_guacamole/features/permissions/voice_permission_prompt.dart';
import 'package:fantastic_guacamole/l10n/chronospark_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
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
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
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

    expect(find.text('Microphone Input'), findsOneWidget);
    expect(find.text('Microphone Permission Denied'), findsOneWidget);
    expect(
      find.textContaining(
        'Spoken playback remains available without microphone access',
      ),
      findsOneWidget,
    );
  });

  testWidgets('voice rationale appears before requesting microphone access', (
    WidgetTester tester,
  ) async {
    int requests = 0;
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
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

    await tester.tap(
      find.widgetWithText(FilledButton, 'Enable Microphone Input'),
    );
    await tester.pumpAndSettle();

    expect(requests, 0);
    expect(find.text('WHEN IT IS USED'), findsOneWidget);
    expect(
      find.text('Spoken playback does not require microphone access'),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Allow Microphone'));
    await tester.pumpAndSettle();

    expect(requests, 1);
  });

  testWidgets('permission kind selects rationale independently of title copy', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const PermissionExplainer customMicrophoneExplainer = PermissionExplainer(
      kind: PermissionKind.microphone,
      title: 'Custom permission title',
      whyItMatters: 'Custom explanation.',
      whenUsed: 'Custom timing.',
      primaryActionLabel: 'Continue',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) {
            return TextButton(
              onPressed: () async {
                await showPermissionRationaleSheet<void>(
                  context: context,
                  explainer: customMicrophoneExplainer,
                  onPrimary: () async {},
                );
              },
              child: const Text('Open rationale'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open rationale'));
    await tester.pumpAndSettle();

    expect(find.text('Custom permission title'), findsOneWidget);
    expect(find.text('PERMISSION · MICROPHONE'), findsOneWidget);
    expect(
      find.text('Spoken playback does not require microphone access'),
      findsOneWidget,
    );
    expect(find.text('PERMISSION · NOTIFICATIONS'), findsNothing);
  });

  testWidgets('Spanish microphone disclosure and rationale stay localized', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('es'),
        supportedLocales: ChronoSparkLocalizations.supportedLocales,
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          ChronoSparkLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: VoicePermissionPrompt(
            permissionGranted: false,
            onRequestPermission: () async => true,
            onOpenSystemSettings: () async {},
          ),
        ),
      ),
    );

    expect(find.text('Entrada por micrófono'), findsOneWidget);
    expect(find.textContaining('solo cuando quieras dictar'), findsOneWidget);
    expect(find.text('Abrir ajustes'), findsOneWidget);
    await tester.tap(find.text('Activar entrada por micrófono'));
    await tester.pumpAndSettle();

    expect(find.text('PERMISO · MICRÓFONO'), findsWidgets);
    expect(find.text('CUÁNDO SE USA'), findsOneWidget);
    expect(
      find.text('La reproducción hablada no requiere acceso al micrófono'),
      findsOneWidget,
    );
    expect(find.text('Allow Microphone'), findsNothing);
  });

  testWidgets('Spanish notification permission remains optional', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('es'),
        supportedLocales: ChronoSparkLocalizations.supportedLocales,
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          ChronoSparkLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: NotificationPermissionPrompt(
            permissionGranted: null,
            onRequestPermission: () async => false,
            onOpenSystemSettings: () async {},
          ),
        ),
      ),
    );

    expect(find.text('Notificaciones'), findsOneWidget);
    expect(
      find.text('Opcionales y controladas desde Ajustes.'),
      findsOneWidget,
    );
    expect(find.text('Activar notificaciones'), findsOneWidget);
  });
}
