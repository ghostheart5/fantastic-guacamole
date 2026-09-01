import 'package:fantastic_guacamole/domain/entities/signal_entity.dart';

/// CHRONOSPARK-CLASS: SHIPPING | Feature: Smart Planner/SI signals
///
/// Bound to SignalRepository.
abstract class ISignalRepository {
  Future<List<SignalEntity>> getSignals();
  Future<void> saveSignal(SignalEntity signal);

  // Optional helpers
  Future<bool> exists(String id);
  Future<void> removeSignal(String id);
  Future<List<SignalEntity>> searchSignals(String query);
}
