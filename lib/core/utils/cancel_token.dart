// lib/core/utils/cancel_token.dart

/// A lightweight cancellation token for cooperative async operation cancellation.
///
/// Pass a [CancelToken] to long-running async operations (AI requests, paywall
/// calls) so they can be cancelled when the initiating widget is disposed.
///
/// Usage:
/// ```dart
/// final token = CancelToken();
///
/// // In the async operation:
/// token.throwIfCancelled();          // throws CancelledException
/// if (token.isCancelled) return;    // soft check variant
///
/// // When done / widget disposed:
/// token.cancel();
/// ```
class CancelToken {
  bool _cancelled = false;

  /// Whether this token has been cancelled.
  bool get isCancelled => _cancelled;

  /// Signals cancellation. Calling this more than once is a no-op.
  void cancel() => _cancelled = true;

  /// Throws a [CancelledException] if this token has been cancelled.
  ///
  /// Call this at cooperative cancellation points inside async operations.
  void throwIfCancelled() {
    if (_cancelled) throw CancelledException();
  }
}

/// Thrown by [CancelToken.throwIfCancelled] when an operation is cancelled.
class CancelledException implements Exception {
  const CancelledException();

  @override
  String toString() => 'CancelledException: operation was cancelled';
}
