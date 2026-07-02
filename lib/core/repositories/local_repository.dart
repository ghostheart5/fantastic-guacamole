import 'package:fantastic_guacamole/core/repositories/base_repository.dart';

abstract class LocalRepository extends BaseRepository {
  Future<void> init();
}
