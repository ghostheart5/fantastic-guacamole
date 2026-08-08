import 'package:fantastic_guacamole/core/utils/cancel_token.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CancelToken', () {
    test('starts in the uncancelled state', () {
      final CancelToken token = CancelToken();
      expect(token.isCancelled, isFalse);
    });

    test('isCancelled returns true after cancel()', () {
      final CancelToken token = CancelToken();
      token.cancel();
      expect(token.isCancelled, isTrue);
    });

    test('cancel() is idempotent — calling it twice does not throw', () {
      final CancelToken token = CancelToken();
      token.cancel();
      expect(() => token.cancel(), returnsNormally);
      expect(token.isCancelled, isTrue);
    });

    test('throwIfCancelled() is silent on an uncancelled token', () {
      final CancelToken token = CancelToken();
      expect(() => token.throwIfCancelled(), returnsNormally);
    });

    test('throwIfCancelled() throws CancelledException on a cancelled token',
        () {
      final CancelToken token = CancelToken();
      token.cancel();
      expect(() => token.throwIfCancelled(), throwsA(isA<CancelledException>()));
    });

    test('throwIfCancelled() remains throwing after multiple calls', () {
      final CancelToken token = CancelToken();
      token.cancel();
      expect(() => token.throwIfCancelled(), throwsA(isA<CancelledException>()));
      expect(() => token.throwIfCancelled(), throwsA(isA<CancelledException>()));
    });

    test('CancelledException has a non-empty string representation', () {
      const CancelledException ex = CancelledException();
      expect(ex.toString(), isNotEmpty);
      expect(ex.toString(), contains('CancelledException'));
    });

    test('independent tokens do not affect each other', () {
      final CancelToken a = CancelToken();
      final CancelToken b = CancelToken();

      a.cancel();

      expect(a.isCancelled, isTrue);
      expect(b.isCancelled, isFalse);
    });
  });
}
