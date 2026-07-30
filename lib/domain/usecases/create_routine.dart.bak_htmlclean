import 'package:fantastic_guacamole/domain/entities/routine_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_routine_repository.dart';

class CreateRoutine {
  const CreateRoutine(this._repository);

  final IRoutineRepository _repository;

  Future<void> call(RoutineEntity routine) => _repository.saveRoutine(routine);
}
