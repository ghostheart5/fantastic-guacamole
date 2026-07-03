import 'package:fantastic_guacamole/data/models/si_state.dart';
import 'package:fantastic_guacamole/data/models/task.dart';
import 'package:fantastic_guacamole/engine/learning/learning_state.dart';
import 'package:fantastic_guacamole/engine/si/ai_personality.dart';

class AgentRequest {
  const AgentRequest({
    required this.prompt,
    this.context = const <String, dynamic>{},
    this.tasks = const <Task>[],
    this.si,
    this.learning,
    this.personality = AIPersonality.coach,
    this.preferredAgent,
  });

  final String prompt;
  final Map<String, dynamic> context;
  final List<Task> tasks;
  final SIState? si;
  final LearningState? learning;
  final AIPersonality personality;
  final String? preferredAgent;

  Map<String, dynamic> toMap() => <String, dynamic>{
    'prompt': prompt,
    'context': context,
    'tasks': tasks,
    'si': si,
    'learning': learning,
    'personality': personality,
    'preferredAgent': preferredAgent,
  };

  Map<String, dynamic> toJson() => <String, dynamic>{
    'prompt': prompt,
    'context': context,
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
