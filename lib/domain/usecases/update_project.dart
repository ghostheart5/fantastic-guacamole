import 'package:fantastic_guacamole/domain/entities/project_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_project_repository.dart';

class UpdateProject {
  const UpdateProject(this._repository);

  final IProjectRepository _repository;

  Future<void> call(ProjectEntity project) => _repository.saveProject(project);
}
