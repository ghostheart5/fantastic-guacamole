import 'package:fantastic_guacamole/domain/entities/task.dart';
import 'package:fantastic_guacamole/engine/si/models/si_state.dart';
import 'package:fantastic_guacamole/engine/learning/learning_state.dart';
import 'package:fantastic_guacamole/engine/si/ai_personality.dart';

class AgentRequest {
  const AgentRequest({
    required this.prompt,
    this.context = const <String, dynamic>{},
    this.history = const <Map<String, String>>[],
    this.tasks = const <Task>[],
    this.si,
    this.learning,
    this.personality = AIPersonality.coach,
    this.preferredAgent,
  });

  final String prompt;
  final Map<String, dynamic> context;
  final List<Map<String, String>> history;
  final List<Task> tasks;
  final SIState? si;
  final LearningState? learning;
  final AIPersonality personality;
  final String? preferredAgent;

  AgentRequest copyWith({
    String? prompt,
    Map<String, dynamic>? context,
    List<Map<String, String>>? history,
    List<Task>? tasks,
    SIState? si,
    LearningState? learning,
    AIPersonality? personality,
    String? preferredAgent,
  }) {
    return AgentRequest(
      prompt: prompt ?? this.prompt,
      context: context ?? this.context,
      history: history ?? this.history,
      tasks: tasks ?? this.tasks,
      si: si ?? this.si,
      learning: learning ?? this.learning,
      personality: personality ?? this.personality,
      preferredAgent: preferredAgent ?? this.preferredAgent,
    );
  }

  AgentRequest mergeRuntimeContext({
    required Map<String, dynamic> runtimeContext,
    List<Map<String, String>>? resolvedHistory,
  }) {
    return copyWith(
      context: <String, dynamic>{...context, ...runtimeContext},
      history: resolvedHistory ?? history,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
    'prompt': prompt,
    'context': context,
    'history': history,
    'tasks': tasks,
    'si': si,
    'learning': learning,
    'personality': personality,
    'preferredAgent': preferredAgent,
  };

  Map<String, dynamic> toJson() => <String, dynamic>{
    'prompt': prompt,
    'context': context,
    'history': history,
    'tasks': tasks.map((Task task) => task.toJson()).toList(),
    'si': {
      'energy': si?.energy,
      'fatigue': si?.fatigue,
      'completedToday': si?.completedToday,
    },
    'learning': learning?.toJson(),
    'personality': personality.name,
    'preferredAgent': preferredAgent,
  };
}
