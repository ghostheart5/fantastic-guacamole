import 'package:fantastic_guacamole/domain/entities/workspace_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_workspace_repository.dart';

/// CHRONOSPARK-CLASS: PLANNED | Feature: Workspace
///
/// Registered as getWorkspaceUseCaseProvider; multi-workspace UI not built yet.
class GetWorkspace {
  GetWorkspace(this.repository);

  final IWorkspaceRepository repository;

  Future<WorkspaceEntity?> call() {
    return repository.getWorkspace();
  }
}
