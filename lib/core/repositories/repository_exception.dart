import 'package:fantastic_guacamole/core/errors/exceptions.dart';

class RepositoryException extends AppException {
  const RepositoryException(super.message);
}

class RepositoryNotFoundException extends RepositoryException {
  const RepositoryNotFoundException(super.message);
}

class RepositoryStorageException extends RepositoryException {
  const RepositoryStorageException(super.message);
}

class RepositoryNetworkException extends RepositoryException {
  const RepositoryNetworkException(super.message);
}
