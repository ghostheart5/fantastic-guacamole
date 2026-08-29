import 'package:fantastic_guacamole/domain/entities/task.dart';
import 'package:fantastic_guacamole/engine/si/models/si_state.dart';
import 'package:fantastic_guacamole/engine/learning/learning_state.dart';
import 'package:fantastic_guacamole/engine/si/ai_personality.dart';

class AgentRequest {
  AgentRequest({
    required this.prompt,
    Map<String, dynamic> context = const <String, dynamic>{},
    List<Map<String, String>> history = const <Map<String, String>>[],
    List<Task> tasks = const <Task>[],
    this.si,
    this.learning,
    this.personality = AIPersonality.planner,
    this.preferredAgent,
  }) : context = Map<String, dynamic>.unmodifiable(
         context.map<String, dynamic>(
           (String key, dynamic value) => MapEntry(key, _freezeValue(value)),
         ),
       ),
       history = List<Map<String, String>>.unmodifiable(
         history.map(
           (Map<String, String> entry) =>
               Map<String, String>.unmodifiable(entry),
         ),
       ),
       tasks = List<Task>.unmodifiable(tasks);

  final String prompt;
  final Map<String, dynamic> context;
  final List<Map<String, String>> history;
  final List<Task> tasks;
  final SIState? si;
  final LearningState? learning;
  final AIPersonality personality;
  final String? preferredAgent;

  static dynamic _freezeValue(dynamic value) {
    if (value is Map<String, dynamic>) {
      return Map<String, dynamic>.unmodifiable(
        value.map<String, dynamic>(
          (String key, dynamic item) => MapEntry(key, _freezeValue(item)),
        ),
      );
    }
    if (value is Map) {
      return Map<Object?, Object?>.unmodifiable(
        value.map<Object?, Object?>(
          (dynamic key, dynamic item) => MapEntry(key, _freezeValue(item)),
        ),
      );
    }
    if (value is List<String>) {
      return List<String>.unmodifiable(value);
    }
    if (value is Iterable) {
      return List<Object?>.unmodifiable(value.map(_freezeValue));
    }
    return value;
  }

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
    'context': Map<String, dynamic>.from(context),
    'history': history
        .map((Map<String, String> entry) => Map<String, String>.from(entry))
        .toList(growable: false),
    'tasks': List<Task>.from(tasks),
    'si': si,
    'learning': learning,
    'personality': personality,
    'preferredAgent': preferredAgent,
  };

  Map<String, dynamic> toJson() => <String, dynamic>{
    'prompt': prompt,
    'context': Map<String, dynamic>.from(context),
    'history': history
        .map((Map<String, String> entry) => Map<String, String>.from(entry))
        .toList(growable: false),
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
