import 'package:fantastic_guacamole/domain/entities/workspace_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_workspace_repository.dart';

class GetWorkspace {
  GetWorkspace(this.repository);

  final IWorkspaceRepository repository;

  Future<WorkspaceEntity?> call() {
    return repository.getWorkspace();
  }
}
