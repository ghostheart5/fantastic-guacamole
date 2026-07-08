import 'package:fantastic_guacamole/data/services/ai/agents/ai_agent.dart';
import 'package:fantastic_guacamole/engine/assistant/assistant_interfaces.dart';
import 'package:fantastic_guacamole/domain/entities/task.dart';
import 'package:fantastic_guacamole/engine/learning/learning_state.dart';
import 'package:fantastic_guacamole/engine/si/ai_personality.dart';
import 'package:fantastic_guacamole/engine/si/ai_response.dart';
import 'package:fantastic_guacamole/engine/si/models/si_state.dart';
import 'package:fantastic_guacamole/engine/si/si_ai_service.dart';

class RecommendationAgent extends AiAgent implements RecommendationEngine {
  const RecommendationAgent({this.service});

  final SIAIService? service;

  @override
  String get name => 'recommendation';

  @override
  Future<Map<String, dynamic>> execute(Map<String, dynamic> request) async {
    final Object? context = request['context'];
    final List<Task> tasks = (request['tasks'] as List<Task>?) ?? const <Task>[];
    final SIState? si = request['si'] as SIState?;
    final LearningState? learning = request['learning'] as LearningState?;
    final AIPersonality personality = request['personality'] is AIPersonality
        ? request['personality'] as AIPersonality
        : AIPersonality.coach;

    final AIResponse response = await (service ?? SIAIService()).generate(
      tasks: tasks,
      si: si ?? const SIState(),
      learning: learning ?? const LearningState(),
      personality: personality,
    );

    return <String, dynamic>{
      'agent': name,
      'mode': 'recommendation',
      'context': context,
      'task': response.task?.toJson(),
      'message': response.message,
      'reasoning': response.reasoning,
      'emotion': response.emotion,
      'confidence': response.confidence,
      'recommendations': <String>[response.message],
      'status': 'ready',
    };
  }
}
