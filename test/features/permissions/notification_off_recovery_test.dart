import 'package:fantastic_guacamole/features/permissions/notification_permission_prompt.dart';
import 'package:fantastic_guacamole/l10n/chronospark_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final language in ['en', 'es']) {
    testWidgets(
      'off notifications keep consent and settings recovery in $language',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 1800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        var requests = 0;
        var settingsOpened = 0;
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(language),
            supportedLocales: ChronoSparkLocalizations.supportedLocales,
            localizationsDelegates: const [
              ChronoSparkLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: Scaffold(
              body: SingleChildScrollView(
                child: NotificationPermissionPrompt(
                  permissionGranted: false,
                  onRequestPermission: () async {
                    requests++;
                    return false;
                  },
                  onOpenSystemSettings: () async {
                    settingsOpened++;
                  },
                ),
              ),
            ),
          ),
        );
        expect(requests, 0);
        expect(settingsOpened, 0);
        final enable = language == 'es'
            ? 'Activar notificaciones'
            : 'Enable Notifications';
        final allow = language == 'es'
            ? 'Permitir notificaciones'
            : 'Allow Notifications';
        final openSettings = language == 'es'
            ? 'Abrir ajustes'
            : 'Open Settings';
        expect(
          find.text(
            language == 'es'
                ? 'Notificaciones desactivadas'
                : 'Notifications off',
          ),
          findsOneWidget,
        );
        expect(
          find.text(
            language == 'es' ? 'Permiso denegado' : 'Permission Denied',
          ),
          findsNothing,
        );
        await tester.tap(find.widgetWithText(FilledButton, enable));
        await tester.pumpAndSettle();
        expect(
          requests,
          0,
          reason: 'Opening the explanation must not ask Android yet.',
        );
        expect(
          find.text(language == 'es' ? 'CUÁNDO SE USA' : 'WHEN IT IS USED'),
          findsOneWidget,
        );
        await tester.tap(find.widgetWithText(FilledButton, allow));
        await tester.pumpAndSettle();
        expect(requests, 1);
        expect(settingsOpened, 0);
        expect(find.text(enable), findsOneWidget);
        await tester.ensureVisible(find.text(openSettings));
        await tester.tap(find.widgetWithText(FilledButton, openSettings));
        await tester.pumpAndSettle();
        expect(
          settingsOpened,
          1,
          reason:
              'Android settings recovery remains a separate explicit choice.',
        );
        expect(requests, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('granted notifications expose no permission actions', (
    tester,
  ) async {
    var requests = 0;
    var settingsOpened = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NotificationPermissionPrompt(
            permissionGranted: true,
            onRequestPermission: () async {
              requests++;
              return true;
            },
            onOpenSystemSettings: () async {
              settingsOpened++;
            },
          ),
        ),
      ),
    );
    expect(find.text('Enable Notifications'), findsNothing);
    expect(find.text('Open Settings'), findsNothing);
    expect(requests, 0);
    expect(settingsOpened, 0);
  });
}
