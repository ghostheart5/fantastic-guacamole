// lib/engine/si/si_reasoning.dart

import 'package:fantastic_guacamole/engine/learning/neural_dump.dart';
import 'package:fantastic_guacamole/engine/si/core/si_reasoning_module.dart';
import 'package:fantastic_guacamole/engine/si/models/si_state.dart';
import 'package:fantastic_guacamole/engine/si/prediction_engine.dart';

class SIReasoningEngine {
  SIReasoningEngine({PredictionEngine? predictionEngine})
    : _module = SIReasoningModule(predictionEngine: predictionEngine);

  final SIReasoningModule _module;

  SICognitionState reason({
    required SIContext context,
    required SIIntent intent,
    required InstinctGuidance instinct,
    List<NeuralEntry> history = const <NeuralEntry>[],
    String task = '',
  }) {
    return _module.process(
      context: context,
      intent: intent,
      instinct: instinct,
      history: history,
      task: task,
    );
  }
}
