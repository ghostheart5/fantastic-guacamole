import 'package:fantastic_guacamole/domain/entities/signal_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_signal_repository.dart';

/// CHRONOSPARK-CLASS: EXPERIMENTAL | Feature: Smart Planner/SI signals
///
/// Exploratory signal capture. No provider yet.
class GenerateSignal {
  GenerateSignal(this.repository);

  final ISignalRepository repository;

  Future<SignalEntity> call(SignalEntity signal) async {
    await repository.saveSignal(signal);
    return signal;
  }
}
