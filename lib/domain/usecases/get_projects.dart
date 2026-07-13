import 'package:fantastic_guacamole/domain/entities/project_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_project_repository.dart';

class GetProjects {
  const GetProjects(this._repository);

  final IProjectRepository _repository;

  List<ProjectEntity> call() => _repository.getProjects();
}
