import 'package:fantastic_guacamole/domain/entities/project_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_project_repository.dart';

/// CHRONOSPARK-CLASS: SHIPPING | Feature: Goals/tasks
///
/// Resolved by projectsProvider.
class CreateProject {
  const CreateProject(this._repository);

  final IProjectRepository _repository;

  Future<void> call(ProjectEntity project) => _repository.saveProject(project);
}
