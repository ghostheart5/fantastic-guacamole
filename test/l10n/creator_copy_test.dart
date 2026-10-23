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
      ('habit', 'el hábito'),
      ('note', 'la nota'),
    ]) {
      final value =
          'This confirmation was already applied. No duplicate ${entry.$1 == 'habit' ? 'daily rhythm' : entry.$1} was created.';
      expect(
        es.message(value),
        'Esta confirmación ya se aplicó. No se duplicó ${entry.$2}.',
      );
      expect(
        en.message(value),
        entry.$1 == 'habit'
            ? 'This confirmation was already applied. No duplicate habit was created.'
            : value,
      );
    }
  });
  test('duration and cadence distinguish singular and plural', () {
    expect(es.duration(const Duration(minutes: 1)), '1 minuto');
    expect(es.duration(const Duration(minutes: 90)), '1 hora 30 min');
    expect(es.repetitions(1, 'weekly'), '1 vez por semana');
    expect(es.repetitions(2, 'monthly'), '2 veces por mes');
    expect(en.duration(const Duration(minutes: 90)), '1 hour 30 min');
  });
  test('plain failure messages keep the unsaved and unchanged boundaries', () {
    for (final message in [
      'No bound Creator operation is selected. Nothing was saved.',
      'Confirmation binding did not match the displayed diff. Nothing was saved.',
      'Creator data changed after this preview. Review the refreshed version before confirming. Nothing was saved.',
      'Creator confirmation requires a verified account boundary. Nothing was saved.',
    ]) {
      expect(en.message(message), endsWith('Nothing was saved.'));
      expect(en.message(message), isNot(contains('binding')));
    }
    expect(
      en.message(
        'Undo is bound to another account. The saved item was not changed.',
      ),
      contains('another account. The saved item was not changed.'),
    );
    expect(
      en.message('The undo window expired. The saved item was not changed.'),
      endsWith('The saved item was not changed.'),
    );
  });
  test(
    'bound preview warnings name shared information without changing consent',
    () {
      for (final entity in ['task', 'goal', 'daily rhythm', 'note']) {
        final message =
            'Review the exact selected change and its governed Person Context warnings. The proposed $entity was not silently rewritten. Explicit confirmation is required; nothing has been saved yet.';
        final noun = entity == 'daily rhythm' ? 'habit' : entity;
        expect(
          en.message(message),
          'Review the exact selected change and warnings based on personal information you shared. The proposed $noun was not silently rewritten. Explicit confirmation is required; nothing has been saved yet.',
        );
        expect(
          es.message(message),
          contains('avisos basados en la información personal que compartiste'),
        );
        expect(
          es.message(message),
          contains('Se requiere tu confirmación; aún no se ha guardado nada.'),
        );
        expect(en.message(message), isNot(contains('Person Context')));
        if (entity == 'daily rhythm') {
          expect(
            es.message(message),
            contains('No se modificó el hábito sin avisarte.'),
          );
        }
      }
    },
  );
  test('legacy habit producer keys retain safety meaning with current nouns', () {
    const cases = <String, String>{
      'The saved replay record does not match the confirmed daily rhythm. Nothing was changed.':
          'The saved replay record does not match the confirmed habit. Nothing was changed.',
      'The target daily rhythm identity is already used by different data. Nothing was changed.':
          'The target habit identity is already used by different data. Nothing was changed.',
      'The undo record no longer matches the confirmed daily rhythm. Nothing was changed.':
          'The undo record no longer matches the confirmed habit. Nothing was changed.',
      'The created daily rhythm changed after confirmation, so automatic undo was blocked.':
          'The created habit changed after confirmation, so automatic undo was blocked.',
    };
    for (final entry in cases.entries) {
      expect(en.message(entry.key), entry.value);
      expect(es.message(entry.key), contains('hábito'));
      expect(es.message(entry.key), isNot(contains('ritmo diario')));
    }
    const entered = 'My Daily Rhythm: José’s habit called "daily rhythm".';
    expect(en.message(entered), entered);
    expect(es.message(entered), entered);
    expect(en.evidence(entered), entered);
    expect(es.evidence(entered), entered);
  });
  test('unrecognized text stays verbatim in both languages', () {
    for (final copy in [en, es]) {
      const original = 'My plan: keep the name Creator and call Ana: tomorrow.';
      expect(copy.message(original), original);
      expect(copy.evidence(original), original);
      expect(
        copy.message('New diagnostic: actual detail.'),
        'New diagnostic: actual detail.',
      );
    }
  });
}
