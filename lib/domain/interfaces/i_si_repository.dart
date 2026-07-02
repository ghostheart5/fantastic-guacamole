import 'package:fantastic_guacamole/domain/entities/si_state_entity.dart';

abstract class ISiRepository {
  Future<SiStateEntity?> getCurrentState();
  Future<void> saveState(SiStateEntity state);
}
