import 'package:fantastic_guacamole/l10n/nexus_copy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
