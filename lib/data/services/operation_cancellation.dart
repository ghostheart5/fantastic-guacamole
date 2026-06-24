import 'dart:async';

class OperationCancelledException implements Exception {
  OperationCancelledException([this.message = 'Operation was cancelled.']);

  final String message;

  @override
  String toString() => message;
}

class CancellationToken {
  CancellationToken._(this._signal);

  final Completer<void> _signal;

  bool get isCancelled => _signal.isCompleted;

  Future<void> get whenCancelled => _signal.future;

  void throwIfCancelled([String message = 'Operation was cancelled.']) {
    if (isCancelled) {
      throw OperationCancelledException(message);
    }
  }
}

class CancellationTokenSource {
  final Completer<void> _signal = Completer<void>();

  late final CancellationToken token = CancellationToken._(_signal);

  bool get isCancelled => _signal.isCompleted;

  void cancel() {
    if (!_signal.isCompleted) {
      _signal.complete();
    }
  }
}

extension CancellationTokenNullableExtension on CancellationToken? {
  bool get isCancellationRequested => this?.isCancelled ?? false;

  void throwIfCancelled([String message = 'Operation was cancelled.']) {
    this?.throwIfCancelled(message);
  }
}
