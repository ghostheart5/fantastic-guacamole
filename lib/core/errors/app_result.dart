class AppFailure {
  const AppFailure(this.message);
  final String message;
}

class NetworkFailure extends AppFailure {
  const NetworkFailure(super.message);
}

class RateLimitFailure extends AppFailure {
  const RateLimitFailure(super.message);
}

class UnexpectedFailure extends AppFailure {
  const UnexpectedFailure(super.message);
}

class Result<T> {
  const Result.ok(this.value) : failure = null;
  const Result.err(this.failure) : value = null;

  final T? value;
  final AppFailure? failure;

  bool get isOk => failure == null;
}
