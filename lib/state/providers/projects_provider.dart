import 'package:fantastic_guacamole/domain/entities/project_entity.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final projectsProvider =
    NotifierProvider<ProjectsNotifier, List<ProjectEntity>>(
      ProjectsNotifier.new,
    );

final projectProvider = projectsProvider;

class ProjectsNotifier extends Notifier<List<ProjectEntity>> {
  @override
  List<ProjectEntity> build() {
    return ref.read(getProjectsUseCaseProvider).call();
  }

  Future<void> add(ProjectEntity project) async {
    await ref.read(createProjectUseCaseProvider).call(project);
    state = [
      project,
      ...state.where((ProjectEntity item) => item.id != project.id),
    ];
  }

  Future<void> update(ProjectEntity project) async {
    await ref.read(updateProjectUseCaseProvider).call(project);
    state = state
        .map((ProjectEntity item) => item.id == project.id ? project : item)
        .toList(growable: false);
  }

  Future<void> remove(String id) async {
    await ref.read(deleteProjectUseCaseProvider).call(id);
    state = state
        .where((ProjectEntity item) => item.id != id)
        .toList(growable: false);
  }

  Future<void> saveAll(List<ProjectEntity> projects) async {
    await ref.read(saveProjectsUseCaseProvider).call(projects);
    state = projects;
  }
}
