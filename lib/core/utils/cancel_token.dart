/// A lightweight token that signals an async operation should be abandoned.
///
/// Create one token per operation, pass it through the call stack, and check
/// [isCancelled] at any cancellation point.  Call [cancel] from the owning
/// widget/state when it is no longer interested in the result (e.g. on
/// `dispose()`).
class CancelToken {
  bool _cancelled = false;

  /// Whether [cancel] has been called.
  bool get isCancelled => _cancelled;

  /// Marks this token as cancelled.  Subsequent checks of [isCancelled] will
  /// return `true`.  Calling [cancel] more than once is a no-op.
  void cancel() {
    _cancelled = true;
  }
}
