class AppException implements Exception {
  final String message;
  const AppException(this.message);

  @override
  String toString() => message;
}

class StorageException extends AppException {
  const StorageException(super.message);
}

class ValidationException extends AppException {
  const ValidationException(super.message);
}
