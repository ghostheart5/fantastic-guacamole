import 'dart:async';
import 'dart:math';

typedef RetryPredicate = bool Function(Object error);

Future<T> runWithRetry<T>({
  required Future<T> Function() action,
  int maxAttempts = 3,
  Duration initialDelay = const Duration(milliseconds: 350),
  double backoffFactor = 2,
  RetryPredicate? retryIf,
}) async {
  assert(maxAttempts >= 1);
  final Random jitter = Random();
  Duration delay = initialDelay;
  Object? lastError;
  StackTrace? lastStack;

  for (int attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      return await action();
    } on Object catch (error, stack) {
      lastError = error;
      lastStack = stack;
      final bool shouldRetry = attempt < maxAttempts &&
          (retryIf == null ? true : retryIf(error));
      if (!shouldRetry) {
        rethrow;
      }

      final int jitterMs = jitter.nextInt(220);
      await Future<void>.delayed(delay + Duration(milliseconds: jitterMs));
      delay = Duration(
        milliseconds: max(
          100,
          (delay.inMilliseconds * backoffFactor).round(),
        ),
      );
    }
  }

  Error.throwWithStackTrace(
    lastError ?? StateError('Retry loop exited unexpectedly.'),
    lastStack ?? StackTrace.current,
  );
}
