import 'package:fantastic_guacamole/core/errors/persisted_payload_failure.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('known persisted-payload failures recover without exposing content', () {
    expect(
      () => handlePersistedPayloadDecodeFailure(
        diagnosticCode: 'storage.test_decode_failed',
        error: const FormatException('private persisted payload'),
        stackTrace: StackTrace.current,
      ),
      returnsNormally,
    );
  });

  test('unexpected failures retain their identity and stack', () {
    final Object unexpected = Exception('unexpected storage outage');
    expect(
      () => handlePersistedPayloadDecodeFailure(
        diagnosticCode: 'storage.test_decode_failed',
        error: unexpected,
        stackTrace: StackTrace.current,
      ),
      throwsA(same(unexpected)),
    );
  });
}
