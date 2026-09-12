import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/state/providers/voice_input_consent_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fantastic_guacamole/features/permissions/voice_input_consent.dart';
import 'package:fantastic_guacamole/l10n/chronospark_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late VoiceInputConsentStore consentStore;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    consentStore = VoiceInputConsentStore(
      AccountStorageScope.authenticated('review-a'),
    );
  });
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
    await tester.runAsync(() => SharedPreferences.getInstance());
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
                  consentStore: consentStore,
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

  testWidgets('approval persists across sessions for the same account', (
    tester,
  ) async {
    int starts = 0;
    await mount(tester, () async {
      starts++;
    });
    await tester.tap(find.text('Dictate'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('may send audio to its servers'),
      findsOneWidget,
    );
    await tapAction(tester, 'Agree and dictate');
    expect(starts, 1);
    consentStore = VoiceInputConsentStore(
      AccountStorageScope.authenticated('review-a'),
    );
    await tester.tap(find.text('Dictate'));
    await tester.pumpAndSettle();
    expect(starts, 2);
    expect(find.text('Agree and dictate'), findsNothing);
  });

  testWidgets(
    'reset requires consent again and another account has no consent',
    (tester) async {
      int starts = 0;
      await mount(tester, () async {
        starts++;
      });
      await tester.tap(find.text('Dictate'));
      await tester.pumpAndSettle();
      await tapAction(tester, 'Agree and dictate');
      await consentStore.revoke();
      await tester.tap(find.text('Dictate'));
      await tester.pumpAndSettle();
      expect(starts, 1);
      await tapAction(tester, 'Agree and dictate');
      consentStore = VoiceInputConsentStore(
        AccountStorageScope.authenticated('review-b'),
      );
      await tester.tap(find.text('Dictate'));
      await tester.pumpAndSettle();
      expect(starts, 2);
      expect(find.text('Agree and dictate'), findsOneWidget);
    },
  );

  testWidgets(
    'account invalidation during disclosure prevents capture and saving',
    (tester) async {
      int starts = 0;
      await mount(tester, () async {
        starts++;
      });
      await tester.tap(find.text('Dictate'));
      await tester.pumpAndSettle();
      consentStore.invalidate();
      await tapAction(tester, 'Agree and dictate');
      expect(starts, 0);
      expect(
        await VoiceInputConsentStore(
          AccountStorageScope.authenticated('review-a'),
        ).isApproved(),
        isFalse,
      );
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
