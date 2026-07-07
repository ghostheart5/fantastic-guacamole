import 'dart:async';

enum AppResultStatus { success, failure }

enum AppResultErrorCode {
  unknown,
  validation,
  timeout,
  network,
  unauthorized,
  notFound,
  conflict,
  unavailable,
}

class AppResult<T> {
  final AppResultStatus status;
  final T? data;
  final String? message;
  final AppResultErrorCode errorCode;
  final Object? error;
  final StackTrace? stackTrace;

  const AppResult._({
    required this.status,
    this.data,
    this.message,
    this.errorCode = AppResultErrorCode.unknown,
    this.error,
    this.stackTrace,
  });

  factory AppResult.success(T data) => AppResult._(status: AppResultStatus.success, data: data);

  factory AppResult.failure(
    String message, {
    AppResultErrorCode errorCode = AppResultErrorCode.unknown,
    Object? error,
    StackTrace? stackTrace,
  }) => AppResult._(
    status: AppResultStatus.failure,
    message: message,
    errorCode: errorCode,
    error: error,
    stackTrace: stackTrace,
  );

  static Future<AppResult<T>> guard<T>(
    Future<T> Function() operation, {
    String Function(Object error)? messageFor,
    AppResultErrorCode Function(Object error)? errorCodeFor,
  }) async {
    try {
      final T value = await operation();
      return AppResult<T>.success(value);
    } on Object catch (error, stackTrace) {
      final String fallbackMessage = error.toString();
      return AppResult<T>.failure(
        messageFor?.call(error) ?? fallbackMessage,
        errorCode: errorCodeFor?.call(error) ?? _inferErrorCode(error),
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  static AppResultErrorCode _inferErrorCode(Object error) {
    final String message = error.toString().toLowerCase();
    if (error is TimeoutException || message.contains('timed out')) {
      return AppResultErrorCode.timeout;
    }
    if (error is ArgumentError || error is FormatException || error is StateError) {
      return AppResultErrorCode.validation;
    }
    if (message.contains('network') ||
        message.contains('socket') ||
        message.contains('connection')) {
      return AppResultErrorCode.network;
    }
    if (message.contains('unauthorized') ||
        message.contains('forbidden') ||
        message.contains('permission')) {
      return AppResultErrorCode.unauthorized;
    }
    if (message.contains('not found')) {
      return AppResultErrorCode.notFound;
    }
    if (message.contains('already exists') || message.contains('conflict')) {
      return AppResultErrorCode.conflict;
    }
    if (message.contains('unavailable') || message.contains('unsupported')) {
      return AppResultErrorCode.unavailable;
    }
    return AppResultErrorCode.unknown;
  }

  bool get isSuccess => status == AppResultStatus.success;
  bool get isFailure => status == AppResultStatus.failure;
}
