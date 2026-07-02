import 'package:fantastic_guacamole/core/repositories/base_repository.dart';
import 'package:fantastic_guacamole/core/repositories/repository_exception.dart';

abstract class RemoteRepository extends BaseRepository {
  @override
  Future<T> wrap<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on RepositoryException {
      rethrow;
    } on Exception catch (e) {
      final String msg = e.toString().toLowerCase();
      if (msg.contains('network') ||
          msg.contains('socket') ||
          msg.contains('connection') ||
          msg.contains('timeout') ||
          msg.contains('unreachable')) {
        throw RepositoryNetworkException(e.toString());
      }
      rethrow;
    }
  }
}
