import 'package:fantastic_guacamole/domain/entities/project_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_project_repository.dart';

class SaveProjects {
  const SaveProjects(this._repository);

  final IProjectRepository _repository;

  Future<void> call(List<ProjectEntity> projects) {
    return _repository.saveProjects(projects);
  }
}
