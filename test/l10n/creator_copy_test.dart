import 'package:fantastic_guacamole/l10n/creator_copy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const es = CreatorCopy(true);
  const en = CreatorCopy(false);
  test('localized context warnings preserve capacity and reported evidence', () {
    expect(
      es.warning(
        'The 25-minute estimate exceeds the fresh user-reported 10-minute capacity.',
      ),
      'Aviso: La estimación de 25 minutos supera la capacidad de 10 minutos que indicaste recientemente.',
    );
    expect(
      es.evidence('boundary: Do not call my manager: contact Ana instead.'),
      'Límite: Do not call my manager: contact Ana instead.',
    );
    expect(
      es.evidence('My own text: leave it alone.'),
      'My own text: leave it alone.',
    );
    expect(en.evidence('boundary: My own text.'), 'boundary: My own text.');
  });
  test('Spanish expired and conflict messages explain preserved state', () {
    expect(
      es.message('The undo window expired. The saved item was not changed.'),
      'El plazo para deshacer caducó. El elemento guardado no cambió.',
    );
    expect(
      es.message(
        'Creator confirmation requires a verified account boundary. Nothing was saved.',
      ),
      'Debes tener una cuenta verificada para confirmar. No se guardó nada.',
    );
    expect(
      es.message(
        'The created task changed after confirmation, so automatic undo was blocked.',
      ),
      'Se modificó la tarea después de confirmar. Para proteger esos cambios, se bloqueó la acción de deshacer.',
    );
    expect(
      es.message('New diagnostic: actual detail.'),
      'New diagnostic: actual detail.',
    );
  });
  test('repeat confirmation names the actual entity in both languages', () {
    for (final entry in [
      ('task', 'la tarea'),
      ('goal', 'la meta'),
      ('habit', 'el ritmo diario'),
      ('note', 'la nota'),
    ]) {
      final value =
          'This confirmation was already applied. No duplicate ${en.kind(entry.$1).toLowerCase()} was created.';
      expect(
        es.message(value),
        'Esta confirmación ya se aplicó. No se duplicó ${entry.$2}.',
      );
      expect(en.message(value), value);
    }
  });
  test('duration and cadence distinguish singular and plural', () {
    expect(es.duration(const Duration(minutes: 1)), '1 minuto');
    expect(es.duration(const Duration(minutes: 90)), '1 hora 30 min');
    expect(es.repetitions(1, 'weekly'), '1 vez por semana');
    expect(es.repetitions(2, 'monthly'), '2 veces por mes');
    expect(en.duration(const Duration(minutes: 90)), '1 hour 30 min');
  });
}
