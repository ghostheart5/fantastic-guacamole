import 'package:fantastic_guacamole/features/permissions/voice_input_consent.dart';
import 'package:fantastic_guacamole/l10n/chronospark_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> mount(
    WidgetTester tester,
    Future<void> Function() onStart, {
    Locale locale = const Locale('en'),
  }) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(
      () => tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        supportedLocales: ChronoSparkLocalizations.supportedLocales,
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          ChronoSparkLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) => TextButton(
              onPressed: () async {
                await startVoiceInputWithConsent(
                  context: context,
                  onStart: onStart,
                );
              },
              child: const Text('Dictate'),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> tapAction(WidgetTester tester, String text) async {
    final Finder action = find.widgetWithText(FilledButton, text);
    await tester.ensureVisible(action);
    await tester.pumpAndSettle();
    await tester.tap(action);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'each dictation requires provider disclosure even after prior consent',
    (WidgetTester tester) async {
      int starts = 0;
      await mount(tester, () async {
        starts++;
      });
      for (int attempt = 0; attempt < 2; attempt++) {
        await tester.tap(find.text('Dictate'));
        await tester.pumpAndSettle();
        expect(starts, attempt);
        final Finder disclosure = find.textContaining(
          'may send audio to its servers',
        );
        expect(disclosure, findsOneWidget);
        await tester.ensureVisible(disclosure);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tapAction(tester, 'Agree and dictate');
        expect(starts, attempt + 1);
      }
    },
  );

  testWidgets('declining provider processing never starts microphone input', (
    WidgetTester tester,
  ) async {
    int starts = 0;
    await mount(tester, () async {
      starts++;
    });
    await tester.tap(find.text('Dictate'));
    await tester.pumpAndSettle();
    final Finder decline = find.widgetWithText(TextButton, 'Not Now');
    await tester.ensureVisible(decline);
    await tester.pumpAndSettle();
    await tester.tap(decline);
    await tester.pumpAndSettle();
    expect(starts, 0);
    expect(find.text('Agree and dictate'), findsNothing);
  });

  testWidgets('consent completed while backgrounded cannot start capture', (
    WidgetTester tester,
  ) async {
    int starts = 0;
    await mount(tester, () async {
      starts++;
    });
    await tester.tap(find.text('Dictate'));
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tapAction(tester, 'Agree and dictate');
    expect(starts, 0);
  });

  testWidgets(
    'Spanish dictation explains server processing before acceptance',
    (WidgetTester tester) async {
      int starts = 0;
      await mount(tester, () async {
        starts++;
      }, locale: const Locale('es'));
      await tester.tap(find.text('Dictate'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('puede enviar audio a sus servidores'),
        findsOneWidget,
      );
      expect(find.text('Agree and dictate'), findsNothing);
      expect(starts, 0);
      await tapAction(tester, 'Aceptar y dictar');
      expect(starts, 1);
    },
  );
}
