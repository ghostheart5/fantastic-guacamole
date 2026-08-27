import 'dart:convert';

import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/data/local/hive_storage.dart';
import 'package:fantastic_guacamole/domain/entities/project_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_project_repository.dart';

class ProjectRepository implements IProjectRepository {
  ProjectRepository(this._store);

  static const String _key = 'projects_v1';

  final HiveStorage<String> _store;

  @override
  List<ProjectEntity> getProjects() {
    String? raw;
    try {
      raw = _store.get(_key);
    } on StateError {
      return const <ProjectEntity>[];
    }
    if (raw == null || raw.trim().isEmpty) {
      return const <ProjectEntity>[];
    }
    try {
      final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map<String, dynamic>>()
          .map(ProjectEntity.fromJson)
          .toList(growable: false);
    } catch (error, stackTrace) {
      // Corrupted payload: return the empty/absent value so the app stays
      // usable, but make it observable instead of silently
      // indistinguishable from "user has no projects".
      Logger.errorCategory(
        'StorageCorruption',
        'Failed to decode stored projects; returning empty result.',
        error,
        stackTrace,
      );
      return const <ProjectEntity>[];
    }
  }

  @override
  Future<void> saveProject(ProjectEntity project) {
    final List<ProjectEntity> existing = getProjects().toList(growable: true);
    final int index = existing.indexWhere(
      (ProjectEntity item) => item.id == project.id,
    );
    if (index >= 0) {
      existing[index] = project;
    } else {
      existing.insert(0, project);
    }
    return saveProjects(existing);
  }

  @override
  Future<void> saveProjects(List<ProjectEntity> projects) {
    return _store.put(
      _key,
      jsonEncode(
        projects.map((ProjectEntity project) => project.toJson()).toList(),
      ),
    );
  }

  @override
  Future<void> deleteProject(String id) {
    final List<ProjectEntity> next = getProjects()
        .where((ProjectEntity project) => project.id != id)
        .toList(growable: false);
    return saveProjects(next);
  }
}
