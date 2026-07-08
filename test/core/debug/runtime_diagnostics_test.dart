import 'package:fantastic_guacamole/core/debug/runtime_diagnostics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    RuntimeDiagnostics.entries.value = <String>[];
    RuntimeDiagnostics.events.value = <RuntimeDiagnosticEvent>[];
  });

  test('record ignores blank input and stores timestamped entries', () {
    RuntimeDiagnostics.record('   ');
    RuntimeDiagnostics.record('startup ok');

    expect(RuntimeDiagnostics.entries.value, hasLength(1));
    expect(RuntimeDiagnostics.entries.value.single, contains('startup ok'));
  });

  test('recordState stores structured event and summary entry', () {
    RuntimeDiagnostics.recordState(
      'startup.complete',
      message: 'ok',
      data: <String, Object?>{'mode': 'prod', 'ready': true},
    );

    expect(RuntimeDiagnostics.events.value, hasLength(1));
    expect(RuntimeDiagnostics.events.value.single.category, 'startup.complete');
    expect(RuntimeDiagnostics.events.value.single.message, 'ok');
    expect(RuntimeDiagnostics.events.value.single.data['mode'], 'prod');
    expect(
      RuntimeDiagnostics.entries.value.single,
      contains('[startup.complete] ok | mode=prod, ready=true'),
    );
  });

  test('recordState trims old entries to max history size', () {
    for (int i = 0; i < 205; i += 1) {
      RuntimeDiagnostics.recordState('pulse', message: 'event $i');
    }

    expect(RuntimeDiagnostics.entries.value, hasLength(200));
    expect(RuntimeDiagnostics.events.value, hasLength(200));
    expect(RuntimeDiagnostics.entries.value.first, contains('event 5'));
    expect(RuntimeDiagnostics.entries.value.last, contains('event 204'));
  });
}
