import 'package:fantastic_guacamole/domain/entities/si_state_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_si_repository.dart';

class HydrateSiState {
  HydrateSiState(this.repository);

  final ISiRepository repository;

  Future<SiStateEntity> call() async {
    return await repository.getCurrentState() ??
        SiStateEntity(energy: 0.7, focus: 0.5, fatigue: 0.3);
  }
}
