import 'dart:async';
import 'dart:math';

import 'package:fantastic_guacamole/core/debug/logger.dart';

class RetryPolicy {
  const RetryPolicy({
    this.maxAttempts = 3,
    this.baseDelay = const Duration(milliseconds: 300),
    this.multiplier = 2.0,
    this.jitter = true,
    this.retryIf,
  });

  final int maxAttempts;
  final Duration baseDelay;
  final double multiplier;
  final bool jitter;
  final bool Function(Object error)? retryIf;

  Future<T> execute<T>(Future<T> Function() fn) async {
    int attempt = 0;
    Duration currentDelay = baseDelay;

    while (true) {
      try {
        return await fn();
      } catch (e) {
        attempt++;

        if (attempt >= maxAttempts || !(retryIf?.call(e) ?? true)) rethrow;

        final Duration delay = jitter
            ? _withJitter(currentDelay)
            : currentDelay;

        Logger.log(
          'RetryPolicy',
          'Attempt $attempt failed → retrying in ${delay.inMilliseconds}ms',
        );

        await Future<void>.delayed(delay);
        currentDelay = Duration(
          milliseconds: (currentDelay.inMilliseconds * multiplier).round(),
        );
      }
    }
  }

  /// Delay for a given attempt number (1-based), without jitter.
  Duration delayFor(int attempt) {
    final int ms = (baseDelay.inMilliseconds * pow(multiplier, attempt - 1))
        .round();
    return Duration(milliseconds: ms);
  }

  Duration _withJitter(Duration delay) {
    final double jitterMs = Random().nextDouble() * delay.inMilliseconds * 0.3;
    return Duration(milliseconds: delay.inMilliseconds + jitterMs.round());
  }
}
