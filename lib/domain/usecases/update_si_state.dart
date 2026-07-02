import 'package:fantastic_guacamole/domain/entities/si_state_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_si_repository.dart';

class UpdateSiState {
  UpdateSiState(this.repository);

  final ISiRepository repository;

  Future<void> call(SiStateEntity state) {
    return repository.saveState(state);
  }
}
