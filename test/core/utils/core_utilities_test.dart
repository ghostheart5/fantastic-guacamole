import 'package:fantastic_guacamole/core/errors/result.dart';
import 'package:fantastic_guacamole/core/extensions/list_extensions.dart';
import 'package:fantastic_guacamole/core/extensions/string_extensions.dart';
import 'package:fantastic_guacamole/core/utils/rate_limiter.dart';
import 'package:fantastic_guacamole/core/utils/throttle.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('throttle reopens after a synchronous action throws', () async {
    final Throttle throttle = Throttle(Duration.zero);

    expect(
      () => throttle.run(() => throw StateError('expected test failure')),
      throwsStateError,
    );
    expect(throttle.isReady, isFalse);

    await Future<void>.delayed(Duration.zero);
    expect(throttle.isReady, isTrue);
    throttle.dispose();
  });

  test('rate limiter validates inputs and releases at the window boundary', () {
    expect(
      () => SlidingWindowRateLimiter(
        maxRequests: 0,
        window: const Duration(minutes: 1),
      ),
      throwsArgumentError,
    );
    expect(
      () => SlidingWindowRateLimiter(maxRequests: 1, window: Duration.zero),
      throwsArgumentError,
    );

    DateTime now = DateTime.utc(2026, 1, 1, 12);
    final SlidingWindowRateLimiter limiter = SlidingWindowRateLimiter(
      maxRequests: 1,
      window: const Duration(minutes: 1),
      now: () => now,
    );

    expect(limiter.tryAcquire(), isTrue);
    expect(limiter.tryAcquire(), isFalse);
    now = now.add(const Duration(minutes: 1));
    expect(limiter.tryAcquire(), isTrue);
  });

  test('result guard never exposes a raw exception by default', () async {
    final AppResult<void> result = await AppResult.guard<void>(
      () async => throw StateError('secret provider detail'),
    );

    expect(result.isFailure, isTrue);
    expect(result.message, 'Something went wrong. Please try again.');
    expect(result.message, isNot(contains('secret provider detail')));
  });

  test('string and list helpers reject unsafe edge cases', () {
    expect('   '.initials, isEmpty);
    expect(() => 'text'.truncate(-1), throwsArgumentError);
    expect(() => <int>[1].chunked(0), throwsArgumentError);
  });
}
