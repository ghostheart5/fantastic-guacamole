import 'package:fantastic_guacamole/l10n/app_language.dart';
import 'package:fantastic_guacamole/l10n/chronospark_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Text built outside widgets (OS reminders) must pick the same language the
/// screens show, which the app derives from the device languages.
void main() {
  for (final (List<Locale> device, bool spanish) in <(List<Locale>, bool)>[
    (const [Locale('es', 'MX')], true),
    (const [Locale('es')], true),
    (const [Locale('en', 'US')], false),
    // Flutter's own rules, as on screen: a supported language further down
    // the list counts, unless a later entry matches exactly.
    (const [Locale('fr'), Locale('es', 'ES')], true),
    (const [Locale('fr'), Locale('en'), Locale('es')], false),
    (const [Locale('fr'), Locale('es', 'ES'), Locale('en')], false),
    // No supported language: English, the app's fallback.
    (const [Locale('fr')], false),
  ]) {
    testWidgets('device languages $device: the app shows '
        '${spanish ? 'Spanish' : 'English'} and reminders agree', (
      tester,
    ) async {
      tester.platformDispatcher.localesTestValue = device;
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      late Locale shown;
      await tester.pumpWidget(
        WidgetsApp(
          color: const Color(0xFF000000),
          supportedLocales: ChronoSparkLocalizations.supportedLocales,
          builder: (context, _) {
            shown = Localizations.localeOf(context);
            return const SizedBox.shrink();
          },
        ),
      );
      expect(shown.languageCode == 'es', spanish);
      expect(appLanguageIsSpanish(), spanish);
      expect(appLanguageIsSpanish(device), spanish);
    });
  }

  test('no device language at all reads as English', () {
    expect(appLanguageIsSpanish(const <Locale>[]), isFalse);
  });
}
