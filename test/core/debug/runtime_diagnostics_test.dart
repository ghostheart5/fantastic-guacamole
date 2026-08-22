import 'package:fantastic_guacamole/core/debug/runtime_diagnostics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    RuntimeDiagnostics.entries.value = <String>[];
    RuntimeDiagnostics.events.value = <RuntimeDiagnosticEvent>[];
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  test('record ignores blank input and stores timestamped entries', () {
    RuntimeDiagnostics.record('   ');
    RuntimeDiagnostics.record('startup ok');

    expect(RuntimeDiagnostics.entries.value, hasLength(1));
    expect(RuntimeDiagnostics.entries.value.single, contains('startup ok'));
  });

  test('record redacts sensitive values before storing a breadcrumb', () {
    RuntimeDiagnostics.record(
      'user@example.com Bearer secret-token password=hunter2',
    );

    final String entry = RuntimeDiagnostics.entries.value.single;
    expect(entry, contains('[redacted-email]'));
    expect(entry, contains('Bearer [redacted-token]'));
    expect(entry, contains('password=[redacted-password]'));
    expect(entry, isNot(contains('user@example.com')));
    expect(entry, isNot(contains('secret-token')));
    expect(entry, isNot(contains('hunter2')));
  });

  test('record trims old entries to max history size', () {
    for (int i = 0; i < 205; i += 1) {
      RuntimeDiagnostics.record('entry $i');
    }

    expect(RuntimeDiagnostics.entries.value, hasLength(200));
    expect(RuntimeDiagnostics.entries.value.first, contains('entry 5'));
    expect(RuntimeDiagnostics.entries.value.last, contains('entry 204'));
  });

  test('breadcrumb guard remains best effort on supported Apple platforms', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(() => RuntimeDiagnostics.record('ios breadcrumb'), returnsNormally);

    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    expect(
      () => RuntimeDiagnostics.record('macos breadcrumb'),
      returnsNormally,
    );

    expect(RuntimeDiagnostics.entries.value, hasLength(2));
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

  test(
    'recordState filters content-bearing keys and redacts safe metadata',
    () {
      RuntimeDiagnostics.recordState(
        ' privacy.check ',
        message: 'owner@example.com',
        data: <String, Object?>{
          'title': 'Private title',
          'freeText': 'Private text',
          'messageBody': 'Private message',
          'promptValue': 'Private prompt',
          'contentType': 'Private content',
          'authToken': 'Private token',
          'deviceName': 'Private device',
          'userId': 'Private id',
          'status': 'Bearer top-secret',
          'attempt': 3,
          'optional': null,
        },
      );

      final RuntimeDiagnosticEvent event =
          RuntimeDiagnostics.events.value.single;
      expect(event.category, 'privacy.check');
      expect(event.message, '[redacted-email]');
      expect(event.data, <String, Object?>{
        'status': 'Bearer [redacted-token]',
        'attempt': '3',
        'optional': '',
      });
      expect(
        RuntimeDiagnostics.entries.value.single,
        isNot(contains('Private')),
      );
    },
  );

  test('recordState uses safe defaults for empty category and message', () {
    RuntimeDiagnostics.recordState('   ', message: '   ');

    final RuntimeDiagnosticEvent event = RuntimeDiagnostics.events.value.single;
    expect(event.category, isEmpty);
    expect(event.message, isEmpty);
    expect(
      RuntimeDiagnostics.entries.value.single,
      contains('[runtime] state updated'),
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
