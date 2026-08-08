import 'package:fantastic_guacamole/domain/entities/si_state_entity.dart';

/// CHRONOSPARK-CLASS: SHIPPING | Feature: SI Console
///
/// Bound to a private adapter over siStateProvider; no persistence yet.
abstract class ISiRepository {
  Future<SiStateEntity?> getCurrentState();
  Future<void> saveState(SiStateEntity state);
}
