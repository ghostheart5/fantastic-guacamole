import 'package:fantastic_guacamole/state/providers/voice_command_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class VoiceCommandHandoff {
  const VoiceCommandHandoff({
    required this.intent,
    required this.originalText,
    required this.normalizedText,
    this.scheduleHint,
    this.frequencyHint,
    this.targetHint,
    required this.createdAt,
  });

  final VoiceCommandIntent intent;
  final String originalText;
  final String normalizedText;
  final String? scheduleHint;
  final String? frequencyHint;
  final String? targetHint;
  final DateTime createdAt;

  bool get isTaskIntent => intent == VoiceCommandIntent.createTask;
  bool get isGoalIntent => intent == VoiceCommandIntent.createGoal;
  bool get isRoutineIntent => intent == VoiceCommandIntent.createRoutine;
  bool get isNoteIntent => intent == VoiceCommandIntent.createNote;
  bool get isMemoryIntent => intent == VoiceCommandIntent.recordMemory;

  bool get shouldOpenCreator =>
      isTaskIntent ||
      isGoalIntent ||
      isRoutineIntent ||
      isNoteIntent ||
      isMemoryIntent;

  String get preferredType {
    if (isGoalIntent) {
      return 'Goal';
    }
    if (isRoutineIntent) {
      return 'Routine';
    }
    if (isNoteIntent || isMemoryIntent) {
      return 'Note';
    }
    return 'Task';
  }

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
        .replaceFirst('create routine', '')
        .replaceFirst('new routine', '')
        .replaceFirst('add routine', '')
        .replaceFirst('make routine', '')
        .replaceFirst('create habit', '')
        .replaceFirst('new habit', '')
        .replaceFirst('add habit', '')
        .replaceFirst('make habit', '')
        .replaceFirst('create note', '')
        .replaceFirst('new note', '')
        .replaceFirst('add note', '')
        .replaceFirst('make note', '')
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
      scheduleHint: result.scheduleHint,
      frequencyHint: result.frequencyHint,
      targetHint: result.targetHint,
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
