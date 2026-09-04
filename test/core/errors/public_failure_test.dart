import 'dart:async';

import 'package:fantastic_guacamole/core/errors/public_failure.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'raw unexpected errors are replaced with the supplied safe fallback',
    () {
      final PublicFailure failure = PublicFailure.from(
        StateError('private provider detail'),
        fallback: 'That action could not be completed. Retry.',
      );

      expect(failure.code, 'unexpected');
      expect(failure.message, 'That action could not be completed. Retry.');
      expect(failure.message, isNot(contains('private provider detail')));
    },
  );

  test('known failure categories provide Spanish-safe messages', () {
    final PublicFailure timeout = PublicFailure.from(
      TimeoutException('private endpoint'),
      isSpanish: true,
    );
    final PublicFailure storage = PublicFailure.from(
      _StorageFailure(),
      isSpanish: true,
    );

    expect(timeout.code, 'timeout');
    expect(timeout.message, contains('tardó demasiado'));
    expect(storage.code, 'network');
    expect(storage.message, contains('trabajo local no cambió'));
    expect(storage.message, isNot(contains('private')));
  });
}

final class _StorageFailure implements Exception {}
