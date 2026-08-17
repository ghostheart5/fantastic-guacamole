import 'dart:async';

/// A user-safe failure envelope. Raw provider exceptions stay inside the
/// diagnostic boundary; user-facing surfaces receive only stable copy and a
/// retry/incident signal.
class PublicFailure implements Exception {
  const PublicFailure({
    required this.code,
    required this.message,
    this.retryable = true,
  });

  final String code;
  final String message;
  final bool retryable;

  @override
  String toString() => message;

  static PublicFailure from(
    Object error, {
    String fallback = 'Something went wrong.',
  }) {
    if (error is PublicFailure) return error;
    if (error is TimeoutException) {
      return const PublicFailure(
        code: 'timeout',
        message: 'The request took too long. Check your connection and retry.',
      );
    }
    final String type = error.runtimeType.toString().toLowerCase();
    if (type.contains('auth')) {
      return const PublicFailure(
        code: 'auth',
        message: 'Your session needs attention. Sign in again and retry.',
      );
    }
    if (type.contains('storage') || type.contains('network')) {
      return const PublicFailure(
        code: 'network',
        message:
            'ChronoSpark could not reach its data service. Your local work is unchanged; retry when connected.',
      );
    }
    return PublicFailure(code: 'unexpected', message: fallback);
  }
}
