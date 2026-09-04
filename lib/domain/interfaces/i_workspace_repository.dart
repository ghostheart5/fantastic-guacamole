import 'package:fantastic_guacamole/domain/entities/workspace_entity.dart';

/// CHRONOSPARK-CLASS: SHIPPING | Feature: Workspace
///
/// Bound to WorkspaceRepository; multi-workspace UI not built yet.
abstract class IWorkspaceRepository {
  Future<WorkspaceEntity?> getWorkspace();
  Future<void> saveWorkspace(WorkspaceEntity workspace);
  Future<void> switchWorkspace(String id);
}
