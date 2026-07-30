import 'package:fantastic_guacamole/domain/entities/project_entity.dart';

abstract class IProjectRepository {
  List<ProjectEntity> getProjects();
  Future<void> saveProject(ProjectEntity project);
  Future<void> saveProjects(List<ProjectEntity> projects);
  Future<void> deleteProject(String id);
}
