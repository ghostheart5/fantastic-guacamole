import 'package:fantastic_guacamole/domain/entities/signal_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_signal_repository.dart';

/// CHRONOSPARK-CLASS: PLANNED | Output: Smart Planner/SI
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
  }) async {
    final DateTime now = DateTime.now();
    final SignalEntity signal = SignalEntity(
      id: 'signal-${now.microsecondsSinceEpoch}',
      title: eventType,
      summary: summary,
      createdAt: now,
      tags: tags,
      action: action,
    );
    await repository.saveSignal(signal);
    return signal;
  }
}
