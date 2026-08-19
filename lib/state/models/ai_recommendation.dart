import 'package:fantastic_guacamole/engine/si/ai_response.dart';
import 'package:fantastic_guacamole/state/models/task_view.dart';

enum AIProcessingMode { unknown, onDevice, external, onDeviceFallback }

AIProcessingMode aiProcessingModeFromMetadata(Map<String, dynamic> metadata) {
  final String source = metadata['source']?.toString().toLowerCase() ?? '';
  final bool modelBacked = metadata['modelBacked'] == true;
  if (modelBacked || source == 'model' || source == 'external') {
    return AIProcessingMode.external;
  }
  if (source == 'failed' || source == 'withheld') {
    return AIProcessingMode.onDeviceFallback;
  }
  if (source == 'notattempted' ||
      source == 'not_attempted' ||
      source == 'local' ||
      source == 'on_device') {
    return AIProcessingMode.onDevice;
  }
  return AIProcessingMode.unknown;
}

class AIRecommendation {
  const AIRecommendation({
    required this.message,
    this.task,
    this.reasoning,
    this.emotion,
    this.confidence,
    this.processingMode = AIProcessingMode.unknown,
  });

  final TaskView? task;
  final String message;
  final String? reasoning;
  final String? emotion;
  final double? confidence;
  final AIProcessingMode processingMode;

  factory AIRecommendation.fromResponse(AIResponse response) {
    final task = response.task;
    return AIRecommendation(
      task: task == null ? null : TaskView.fromTask(task),
      message: response.message,
      reasoning: response.reasoning,
      emotion: response.emotion,
      confidence: response.confidence,
      processingMode: aiProcessingModeFromMetadata(response.metadata),
    );
  }
}
