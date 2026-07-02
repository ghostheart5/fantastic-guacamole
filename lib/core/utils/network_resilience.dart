import 'dart:async';
import 'dart:io';
import 'dart:math';

class NetworkResilience {
  static final Random _random = Random();

  /// Runs [request] with automatic retry on transient network errors.
  ///
  /// Retries on [SocketException], [HttpException], and [TimeoutException].
  /// Uses exponential backoff with jitter between attempts.
  static Future<T> run<T>(
    Future<T> Function() request, {
    Duration timeout = const Duration(seconds: 12),
    int maxAttempts = 3,
  }) async {
    assert(maxAttempts >= 1);

    late Object lastError;
    late StackTrace lastStack;

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        return await request().timeout(timeout);
      } on SocketException catch (e, s) {
        lastError = e;
        lastStack = s;
      } on HttpException catch (e, s) {
        lastError = e;
        lastStack = s;
      } on TimeoutException catch (e, s) {
        lastError = e;
        lastStack = s;
      }

      if (attempt < maxAttempts) {
        await Future<void>.delayed(_backoffFor(attempt));
      }
    }

    Error.throwWithStackTrace(lastError, lastStack);
  }

  /// Parses a Retry-After header value into a [Duration].
  ///
  /// Accepts integer seconds or an absolute HTTP-date string.
  /// Returns null if the value is absent or unparseable.
  /// Clamps result to 1–30 seconds.
  static Duration? parseRetryAfter(String? value) {
    if (value == null || value.trim().isEmpty) return null;

    final int? seconds = int.tryParse(value.trim());
    if (seconds != null) {
      return Duration(seconds: seconds.clamp(1, 30));
    }

    final DateTime? absolute = DateTime.tryParse(value);
    if (absolute == null) return null;

    final Duration diff = absolute.difference(DateTime.now().toUtc());
    if (diff.isNegative) return const Duration(seconds: 1);
    if (diff.inSeconds > 30) return const Duration(seconds: 30);
    return diff;
  }

  static Duration _backoffFor(int attempt) {
    final int baseMillis = switch (attempt) {
      1 => 350,
      2 => 900,
      _ => 1500,
    };
    final int jitter = _random.nextInt(251);
    return Duration(milliseconds: baseMillis + jitter);
  }
}
