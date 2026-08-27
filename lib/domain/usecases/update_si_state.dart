import 'package:fantastic_guacamole/domain/entities/si_state_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_si_repository.dart';

/// CHRONOSPARK-CLASS: PLANNED | Feature: SI Console
///
/// Registered as updateSiStateUseCaseProvider; SI state is currently held in
/// siStateProvider, not persisted.
class UpdateSiState {
  UpdateSiState(this.repository);

  final ISiRepository repository;

  Future<void> call(SiStateEntity state) {
    return repository.saveState(state);
  }
}
