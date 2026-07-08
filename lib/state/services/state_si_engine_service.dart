import 'package:fantastic_guacamole/data/repositories/si_engine_repository.dart';
import 'package:fantastic_guacamole/engine/si/ai_response.dart';
import 'package:fantastic_guacamole/engine/si/si_response_policy.dart';
import 'package:fantastic_guacamole/state/services/si_engine_dependencies.dart';

class StateSiEngineService {
  StateSiEngineService(this._repository, {required this.dependencies});

  final SiEngineRepository _repository;
  final SiEngineDependencies dependencies;

  Future<Map<String, dynamic>?> loadState() => _repository.loadState();

  Future<void> saveState(Map<String, dynamic> state) =>
      _repository.saveState(state);

  Future<Map<String, dynamic>> generateResponse({
    required String input,
    required String message,
    String emotion = 'balanced',
    double confidence = 0.5,
    String? taskId,
    Map<String, dynamic> context = const <String, dynamic>{},
  }) async {
    final AIResponse response = AIResponse(
      task: null,
      message: message,
      reasoning: context['reasoning']?.toString() ?? message,
      emotion: emotion,
      confidence: confidence,
    );

    return <String, dynamic>{
      'input': input,
      'taskId': taskId,
      'message': response.message,
      'reasoning': response.reasoning,
      'emotion': response.emotion,
      'confidence': response.confidence,
      'responseHash': responseHashFor(response.message),
      'responseSummary': responseSummaryFor(response.message),
    };
  }

  Map<String, dynamic> updateMemory({
    required Map<String, dynamic>? currentState,
    required Map<String, dynamic> memoryEvent,
  }) {
    final dynamic rawEvents = currentState?['memoryEvents'];
    final List<Map<String, dynamic>> events = rawEvents is List
        ? rawEvents
              .whereType<Map<dynamic, dynamic>>()
              .map((Map<dynamic, dynamic> e) => e.cast<String, dynamic>())
              .toList(growable: true)
        : <Map<String, dynamic>>[];
    events.add(memoryEvent);

    return <String, dynamic>{
      ...?currentState,
      'updatedAtUtc': DateTime.now().toUtc().toIso8601String(),
      'memoryEvents': events.length > 120
          ? events.sublist(events.length - 120)
          : events,
      'memoryEvent': memoryEvent,
    };
  }

  bool validateOutput({
    required String message,
    required double confidence,
    bool coherent = true,
    bool deduped = true,
    bool policyAccepted = true,
    bool grounded = true,
  }) {
    final String text = message.trim();
    if (text.isEmpty) {
      return false;
    }
    if (!isPolicyAcceptableResponse(text)) {
      return false;
    }
    if (confidence < 0.3) {
      return false;
    }
    if (text.toLowerCase().contains('as an ai language model')) {
      return false;
    }
    return coherent && deduped && policyAccepted && grounded;
  }
}
