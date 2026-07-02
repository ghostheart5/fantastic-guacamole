import 'package:fantastic_guacamole/domain/interfaces/i_workspace_repository.dart';

class SwitchWorkspace {
  SwitchWorkspace(this.repository);

  final IWorkspaceRepository repository;

  Future<void> call(String id) {
    return repository.switchWorkspace(id);
  }
}
