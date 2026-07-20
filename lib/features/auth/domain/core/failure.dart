class AuthFailure implements Exception {
  const AuthFailure({
    required this.code,
    required this.message,
    this.details,
  });

  final String code;
  final String message;
  final Object? details;

  @override
  String toString() {
    if (details == null) {
      return 'AuthFailure($code, $message)';
    }
    return 'AuthFailure($code, $message, details: $details)';
  }
}
