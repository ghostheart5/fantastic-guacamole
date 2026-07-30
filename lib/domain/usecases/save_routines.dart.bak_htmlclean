import 'package:fantastic_guacamole/domain/entities/routine_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_routine_repository.dart';

class SaveRoutines {
  const SaveRoutines(this._repository);

  final IRoutineRepository _repository;

  Future<void> call(List<RoutineEntity> routines) {
    return _repository.saveRoutines(routines);
  }
}
