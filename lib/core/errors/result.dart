enum AppResultStatus { success, failure }

class AppResult<T> {
  final AppResultStatus status;
  final T? data;
  final String? message;

  const AppResult._({required this.status, this.data, this.message});

  factory AppResult.success(T data) =>
      AppResult._(status: AppResultStatus.success, data: data);

  factory AppResult.failure(String message) =>
      AppResult._(status: AppResultStatus.failure, message: message);

  bool get isSuccess => status == AppResultStatus.success;
  bool get isFailure => status == AppResultStatus.failure;
}
