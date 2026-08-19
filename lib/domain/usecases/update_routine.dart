import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_routine_repository.dart';

/// CHRONOSPARK-CLASS: SHIPPING | Feature: Future automation
///
/// Resolved by routinesProvider.
class UpdateRoutine {
  const UpdateRoutine(this._repository);

  final IRoutineRepository _repository;

  Future<void> call(HabitEntity routine) => _repository.saveRoutine(routine);
}
