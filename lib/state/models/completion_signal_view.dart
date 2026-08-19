import 'package:fantastic_guacamole/engine/signals/signal_engine.dart';

class CompletionSignalView {
  const CompletionSignalView({
    required this.summary,
    required this.observation,
    required this.suggestion,
  });

  final String summary;
  final String observation;
  final String suggestion;

  factory CompletionSignalView.fromSignal(CompletionSignal signal) {
    return CompletionSignalView(
      summary: signal.summary,
      observation: signal.observation,
      suggestion: signal.suggestion,
    );
  }
}
