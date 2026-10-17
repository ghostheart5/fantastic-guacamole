import 'package:fantastic_guacamole/l10n/nexus_copy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() {
  for (final spanish in [false, true]) {
    testWidgets(
      'upcoming occurrence copy uses explicit reference across year boundary $spanish',
      (tester) async {
        final now = DateTime(2026, 12, 31, 23, 59);
        final occurrence = DateTime(2027, 1, 1, 20);
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(spanish ? 'es' : 'en'),
            supportedLocales: const [Locale('en'), Locale('es')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: Builder(
              builder: (context) => Text(
                NexusCopy(
                  spanish,
                ).upcomingOccurrence(context, occurrence, now: now),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text(
            spanish
                ? 'Próxima ocurrencia · Mañana · 20:00'
                : 'Upcoming occurrence · Tomorrow · 8:00 PM',
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  test('Spanish Nexus copy localizes system actions and delay consequences', () {
    const NexusCopy copy = NexusCopy(true);

    expect(
      copy.systemAction('Work on: Buy groceries'),
      'Trabaja en: Buy groceries',
    );
    expect(
      copy.delayed(
        'Waiting leaves the current priority unresolved and makes your next step less clear.',
      ),
      'SI ESPERAS: La prioridad actual queda sin resolver y el siguiente paso será menos claro.',
    );
    expect(
      copy.delayed(
        'Without reducing or moving work, 45 minutes remain outside available capacity.',
      ),
      'SI ESPERAS: Sin reducir ni mover trabajo, 45 minutos quedan fuera de la capacidad disponible.',
    );
  });
}
