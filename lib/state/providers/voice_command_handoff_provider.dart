import 'package:fantastic_guacamole/state/providers/voice_command_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class VoiceCommandHandoff {
  const VoiceCommandHandoff({
    required this.intent,
    required this.originalText,
    required this.normalizedText,
    required this.createdAt,
  });

  final VoiceCommandIntent intent;
  final String originalText;
  final String normalizedText;
  final DateTime createdAt;

  bool get isTaskIntent => intent == VoiceCommandIntent.createTask;
  bool get isGoalIntent => intent == VoiceCommandIntent.createGoal;
  bool get isMemoryIntent => intent == VoiceCommandIntent.recordMemory;

  bool get shouldOpenCreator => isTaskIntent || isGoalIntent || isMemoryIntent;

  String get suggestedTitle {
    final String cleaned = normalizedText
        .replaceFirst('create task', '')
        .replaceFirst('new task', '')
        .replaceFirst('add task', '')
        .replaceFirst('make task', '')
        .replaceFirst('create goal', '')
        .replaceFirst('new goal', '')
        .replaceFirst('add goal', '')
        .replaceFirst('make goal', '')
        .replaceFirst('record memory', '')
        .replaceFirst('save memory', '')
        .replaceFirst('remember this', '')
        .replaceFirst('capture memory', '')
        .trim();

    if (cleaned.isEmpty) {
      return originalText.trim();
    }

    return cleaned;
  }
}

class VoiceCommandHandoffController extends Notifier<VoiceCommandHandoff?> {
  @override
  VoiceCommandHandoff? build() => null;

  void setFromResult(VoiceCommandResult result) {
    state = VoiceCommandHandoff(
      intent: result.intent,
      originalText: result.originalText,
      normalizedText: result.normalizedText,
      createdAt: DateTime.now(),
    );
  }

  void clear() {
    state = null;
  }
}

final voiceCommandHandoffProvider =
    NotifierProvider<VoiceCommandHandoffController, VoiceCommandHandoff?>(
      VoiceCommandHandoffController.new,
    );
