import 'package:fantastic_guacamole/domain/entities/routine_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_routine_repository.dart';

/// CHRONOSPARK-CLASS: SHIPPING | Feature: Future automation
///
/// Resolved by routinesProvider.
class GetRoutines {
  const GetRoutines(this._repository);

  final IRoutineRepository _repository;

  List<RoutineEntity> call() => _repository.getRoutines();
}
