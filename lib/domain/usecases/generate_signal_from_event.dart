import 'package:fantastic_guacamole/domain/entities/signal_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_signal_repository.dart';

/// CHRONOSPARK-CLASS: PLANNED | Feature: Smart Planner/SI signals
///
/// Registered as generateSignalFromEventUseCaseProvider.
class GenerateSignalFromEvent {
  GenerateSignalFromEvent(this.repository);

  final ISignalRepository repository;

  Future<SignalEntity> call({
    required String eventType,
    required String summary,
    List<String> tags = const <String>[],
    String? action,
    DateTime? now,
  }) async {
    final DateTime timestamp = now ?? DateTime.now();
    final SignalEntity signal = SignalEntity(
      id: 'signal-${timestamp.microsecondsSinceEpoch}',
      title: eventType,
      summary: summary,
      createdAt: timestamp,
      tags: tags,
      action: action,
    );
    await repository.saveSignal(signal);
    return signal;
  }
}
