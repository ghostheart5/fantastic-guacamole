import 'package:fantastic_guacamole/l10n/auth_status_copy.dart';
import 'package:fantastic_guacamole/l10n/chronospark_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sign-in notices are plain words with the same meaning in both languages.
void main() {
  const Map<String, String> plain = <String, String>{
    'Email link opened. If you are not signed in yet, sign in to continue.':
        'Se abrió el enlace del correo. Si aún no has iniciado sesión, inicia sesión para continuar.',
    'Sign-in link opened. Finishing sign-in.':
        'Se abrió el enlace de acceso. Terminando de iniciar sesión.',
    'Use at least 8 characters, with an uppercase letter, a lowercase letter and a number.':
        'Usa al menos 8 caracteres, con una mayúscula, una minúscula y un número.',
    'Enter your account email, then tap Forgot Password? again.':
        'Introduce el correo de tu cuenta y vuelve a tocar ¿Olvidaste la contraseña?.',
  };

  for (final bool es in <bool>[false, true]) {
    testWidgets('${es ? 'Spanish' : 'English'} sign-in notices', (
      WidgetTester tester,
    ) async {
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(es ? 'es' : 'en'),
          supportedLocales: ChronoSparkLocalizations.supportedLocales,
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            ChronoSparkLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Builder(
            builder: (BuildContext built) {
              context = built;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      for (final MapEntry<String, String> entry in plain.entries) {
        expect(
          authStatusText(context, entry.key),
          es ? entry.value : entry.key,
        );
      }
      for (final String stale in <String>[
        'Email verification callback received. Continue sign-in if needed.',
        'Authentication callback received. Continuing sign-in flow.',
      ]) {
        // No longer a known notice: it would show untranslated.
        expect(authStatusText(context, stale), stale);
      }
    });
  }
}
