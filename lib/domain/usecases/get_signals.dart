import 'package:fantastic_guacamole/domain/entities/signal_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_signal_repository.dart';

/// CHRONOSPARK-CLASS: PLANNED | Output: Smart Planner/SI
///
/// Registered as getSignalsUseCaseProvider; signals UI reads
/// signalsBundleProvider.
class GetSignals {
  GetSignals(this.repository);

  final ISignalRepository repository;

  Future<List<SignalEntity>> call() {
    return repository.getSignals();
  }
}
