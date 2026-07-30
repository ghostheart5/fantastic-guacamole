import 'package:fantastic_guacamole/domain/entities/routine_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_routine_repository.dart';

class GetRoutines {
  const GetRoutines(this._repository);

  final IRoutineRepository _repository;

  List<RoutineEntity> call() => _repository.getRoutines();
}
