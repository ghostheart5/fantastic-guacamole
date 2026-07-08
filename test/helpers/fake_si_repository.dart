import 'package:fantastic_guacamole/domain/entities/si_state_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_si_repository.dart';

class FakeSiRepository implements ISiRepository {
  FakeSiRepository({SiStateEntity? initialState}) : _state = initialState;

  SiStateEntity? _state;

  @override
  Future<SiStateEntity?> getCurrentState() async => _state;

  @override
  Future<void> saveState(SiStateEntity state) async {
    _state = state;
  }
}
