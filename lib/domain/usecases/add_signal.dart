import 'package:fantastic_guacamole/domain/entities/signal_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_signal_repository.dart';

/// CHRONOSPARK-CLASS: PLANNED | Output: Smart Planner/SI
///
/// Registered as addSignalUseCaseProvider. Calls SignalEntity.validate().
class AddSignal {
  AddSignal(this.repository);

  final ISignalRepository repository;

  Future<SignalEntity> call(SignalEntity signal) async {
    signal.validate();
    await repository.saveSignal(signal);
    return signal;
  }
}
