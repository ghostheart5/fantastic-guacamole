enum AppResultStatus { success, failure }

class AppResult<T> {
  final AppResultStatus status;
  final T? data;
  final String? message;
  final Object? error;
  final StackTrace? stackTrace;

  const AppResult._({required this.status, this.data, this.message, this.error, this.stackTrace});

  factory AppResult.success(T data) => AppResult._(status: AppResultStatus.success, data: data);

  factory AppResult.failure(String message, {Object? error, StackTrace? stackTrace}) => AppResult._(
    status: AppResultStatus.failure,
    message: message,
    error: error,
    stackTrace: stackTrace,
  );

  static Future<AppResult<T>> guard<T>(
    Future<T> Function() operation, {
    String Function(Object error)? messageFor,
  }) async {
    try {
      final T value = await operation();
      return AppResult<T>.success(value);
    } on Exception catch (error, stackTrace) {
      final String fallbackMessage = error.toString();
      return AppResult<T>.failure(
        messageFor?.call(error) ?? fallbackMessage,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  bool get isSuccess => status == AppResultStatus.success;
  bool get isFailure => status == AppResultStatus.failure;
}
