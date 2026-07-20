enum ResultStatus { success, failure }

class Result<T> {
  const Result._({
    required this.status,
    this.value,
    this.failure,
  });

  const factory Result.success(T value) = SuccessResult<T>._;
  const factory Result.failure(Object failure) = FailureResult<T>._;

  final ResultStatus status;
  final T? value;
  final Object? failure;

  bool get isSuccess => status == ResultStatus.success;
  bool get isFailure => status == ResultStatus.failure;

  R fold<R>({
    required R Function(T value) onSuccess,
    required R Function(Object failure) onFailure,
  }) {
    return switch (this) {
      SuccessResult<T>(:final T value) => onSuccess(value),
      FailureResult<T>(:final Object failure) => onFailure(failure),
      _ => onFailure(failure ?? StateError('Unknown result state')),
    };
  }

  T? getOrNull() => value;
  Object? getFailureOrNull() => failure;
}

class SuccessResult<T> extends Result<T> {
  const SuccessResult._(T value)
      : super._(status: ResultStatus.success, value: value);
}

class FailureResult<T> extends Result<T> {
  const FailureResult._(Object failure)
      : super._(status: ResultStatus.failure, failure: failure);
}

extension ResultGuardX<T> on Result<T> {
  static Future<Result<R>> guard<R>(Future<R> Function() action) async {
    try {
      final R value = await action();
      return Result<R>.success(value);
    } catch (error) {
      return Result<R>.failure(error);
    }
  }
}
