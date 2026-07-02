import 'package:fantastic_guacamole/core/errors/exceptions.dart';
import 'package:fantastic_guacamole/core/repositories/repository_exception.dart';

abstract class BaseRepository {
  void dispose() {}

  Future<T> wrap<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on RepositoryException {
      rethrow;
    } on StorageException catch (e) {
      throw RepositoryStorageException(e.message);
    } on Exception catch (e) {
      throw RepositoryException(e.toString());
    }
  }
}
