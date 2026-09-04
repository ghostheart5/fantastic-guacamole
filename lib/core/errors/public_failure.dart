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

  Map<String, dynamic> toEnvelope() => <String, dynamic>{
    'code': code,
    'message': message,
    'retryable': retryable,
  };

  static PublicFailure from(
    Object error, {
    String fallback = 'Something went wrong.',
    bool isSpanish = false,
  }) {
    if (error is PublicFailure) return error;
    if (error is TimeoutException) {
      return PublicFailure(
        code: 'timeout',
        message: isSpanish
            ? 'La solicitud tardó demasiado. Comprueba tu conexión e inténtalo de nuevo.'
            : 'The request took too long. Check your connection and retry.',
      );
    }
    final String type = error.runtimeType.toString().toLowerCase();
    if (type.contains('auth')) {
      return PublicFailure(
        code: 'auth',
        message: isSpanish
            ? 'Tu inicio de sesión necesita atención. Inicia sesión de nuevo e inténtalo otra vez.'
            : 'Your sign-in needs attention. Sign in again and retry.',
      );
    }
    if (type.contains('storage') || type.contains('network')) {
      return PublicFailure(
        code: 'network',
        message: isSpanish
            ? 'ChronoSpark no pudo comunicarse con su servicio de datos. Tu trabajo local no cambió; inténtalo de nuevo cuando tengas conexión.'
            : 'ChronoSpark could not reach its data service. Your local work is unchanged; retry when connected.',
      );
    }
    return PublicFailure(code: 'unexpected', message: fallback);
  }
}

class PublicErrorEnvelope {
  const PublicErrorEnvelope({
    required this.failure,
    required this.recoveryAction,
  });

  final PublicFailure failure;
  final String recoveryAction;

  Map<String, dynamic> toJson() => <String, dynamic>{
    ...failure.toEnvelope(),
    'recoveryAction': recoveryAction,
  };

  static PublicErrorEnvelope from(
    Object error, {
    String fallback = 'Something went wrong.',
    String recoveryAction = 'retry',
    bool isSpanish = false,
  }) {
    return PublicErrorEnvelope(
      failure: PublicFailure.from(
        error,
        fallback: fallback,
        isSpanish: isSpanish,
      ),
      recoveryAction: recoveryAction,
    );
  }
}
