import 'dart:async';

typedef RetryPredicate = bool Function(Object error, StackTrace stackTrace);

Future<T> retry<T>(
  Future<T> Function() action, {
  int maxAttempts = 3,
  Duration initialDelay = const Duration(milliseconds: 250),
  RetryPredicate? shouldRetry,
}) async {
  if (maxAttempts < 1) {
    throw ArgumentError.value(maxAttempts, 'maxAttempts', 'Must be at least 1.');
  }

  Duration delay = initialDelay;
  Object? lastError;
  StackTrace? lastStackTrace;

  for (int attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      return await action();
    } catch (error, stackTrace) {
      lastError = error;
      lastStackTrace = stackTrace;

      final bool retryable = shouldRetry?.call(error, stackTrace) ?? true;
      if (attempt == maxAttempts || !retryable) {
        Error.throwWithStackTrace(error, stackTrace);
      }

      await Future<void>.delayed(delay);
      delay *= 2;
    }
  }

  Error.throwWithStackTrace(lastError!, lastStackTrace!);
}
