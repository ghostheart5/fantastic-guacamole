import 'package:fantastic_guacamole/domain/interfaces/i_workspace_repository.dart';
import 'package:fantastic_guacamole/domain/policies/input_guard.dart';

/// CHRONOSPARK-CLASS: PLANNED | Feature: Workspace
///
/// Registered as switchWorkspaceUseCaseProvider; multi-workspace UI not built
/// yet. Blank-id guarded.
class SwitchWorkspace {
  SwitchWorkspace(this.repository);

  final IWorkspaceRepository repository;

  Future<void> call(String id) {
    return repository.switchWorkspace(InputGuard.id(id, 'id'));
  }
}
