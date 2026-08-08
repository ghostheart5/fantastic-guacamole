import 'package:fantastic_guacamole/domain/interfaces/i_project_repository.dart';
import 'package:fantastic_guacamole/domain/policies/input_guard.dart';

/// CHRONOSPARK-CLASS: SHIPPING | Feature: Goals/tasks
///
/// Resolved by projectsProvider. Blank-id guarded.
class DeleteProject {
  const DeleteProject(this._repository);

  final IProjectRepository _repository;

  Future<void> call(String id) =>
      _repository.deleteProject(InputGuard.id(id, 'id'));
}
