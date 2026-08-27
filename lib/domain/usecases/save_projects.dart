import 'package:fantastic_guacamole/domain/entities/project_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_project_repository.dart';
import 'package:fantastic_guacamole/domain/policies/input_guard.dart';

/// CHRONOSPARK-CLASS: SHIPPING | Feature: Goals/tasks
///
/// Resolved by projectsProvider. Empty-batch guarded.
/// Replaces the whole stored project collection. Pass `allowClear: true` to
/// clear it deliberately; an empty list is otherwise rejected as an accident.
class SaveProjects {
  const SaveProjects(this._repository);

  final IProjectRepository _repository;

  Future<void> call(List<ProjectEntity> projects, {bool allowClear = false}) {
    return _repository.saveProjects(
      InputGuard.batch(projects, 'projects', allowClear: allowClear),
    );
  }
}
