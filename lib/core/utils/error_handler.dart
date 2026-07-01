import 'package:firebase_auth/firebase_auth.dart';

/// Error categorization and user-friendly messaging
class ErrorHandler {
  static const Map<String, String> authErrorMessages = {
    'user-not-found': 'Email not registered. Please create an account first.',
    'wrong-password': 'Incorrect password. Try again or use "Forgot Password".',
    'invalid-email': 'Please enter a valid email address.',
    'user-disabled': 'This account has been disabled. Contact support.',
    'too-many-requests':
        'Too many login attempts. Please try again in a few minutes.',
    'operation-not-allowed': 'Sign-in is currently disabled. Please try later.',
    'invalid-credential': 'Invalid email or password. Please try again.',
    'network-request-failed': 'Network error. Check your connection and try again.',
    'internal-error': 'An internal error occurred. Please try again.',
  };

  static const Map<String, String> purchaseErrorMessages = {
    'user-not-found': 'Account not found. Please sign in first.',
    'permission-denied': 'You do not have permission to make this purchase.',
    'failed-precondition':
        'Invalid state for purchase. Please restart the app and try again.',
    'invalid-argument': 'Invalid purchase parameters. Please contact support.',
    'unavailable': 'Payment service is currently unavailable. Please try later.',
    'deadline-exceeded': 'Purchase request timed out. Please try again.',
    'internal': 'Payment processing failed. Please try again or contact support.',
    'transient-error':
        'Temporary payment service issue. Please try again in a moment.',
  };

  static const Map<String, String> networkErrorMessages = {
    'SocketException': 'Network connection failed. Check your internet.',
    'TimeoutException': 'Request timed out. Check your connection and try again.',
    'ClientException': 'Communication error. Please try again.',
    'HandshakeException': 'Secure connection failed. Please try again.',
  };

  /// Get user-friendly error message for Firebase Auth exceptions
  static String getUserFriendlyAuthError(FirebaseAuthException e) {
    return authErrorMessages[e.code] ??
        authErrorMessages['internal-error'] ??
        'Authentication failed: ${e.message}';
  }

  /// Get user-friendly error message for purchase errors
  static String getUserFriendlyPurchaseError(Object error) {
    final errorString = error.toString();

    // Check for known error codes
    for (final entry in purchaseErrorMessages.entries) {
      if (errorString.contains(entry.key)) {
        return entry.value;
      }
    }

    // Check for network errors
    for (final entry in networkErrorMessages.entries) {
      if (errorString.contains(entry.key)) {
        return entry.value;
      }
    }

    return 'Purchase failed. Please try again or contact support.';
  }

  /// Categorize error severity
  static ErrorSeverity categorizeError(Object error) {
    final errorString = error.toString().toLowerCase();

    if (errorString.contains('network') ||
        errorString.contains('socket') ||
        errorString.contains('timeout')) {
      return ErrorSeverity.transient;
    }

    if (errorString.contains('permission') ||
        errorString.contains('unauthorized') ||
        errorString.contains('forbidden')) {
      return ErrorSeverity.auth;
    }

    if (errorString.contains('not-found') ||
        errorString.contains('invalid')) {
      return ErrorSeverity.user;
    }

    return ErrorSeverity.unknown;
  }

  /// Determine if error is retryable
  static bool isRetryable(Object error) {
    final severity = categorizeError(error);
    return severity == ErrorSeverity.transient;
  }

  /// Determine if error should be shown to user
  static bool shouldShowToUser(Object error) {
    final severity = categorizeError(error);
    return severity != ErrorSeverity.unknown;
  }
}

enum ErrorSeverity {
  /// Transient network/timeout errors (retryable)
  transient,

  /// Authentication/authorization errors
  auth,

  /// User input/validation errors
  user,

  /// Server/internal errors
  server,

  /// Unknown error type
  unknown,
}
