import 'package:fantastic_guacamole/data/repositories/si_engine_repository.dart';
import 'package:fantastic_guacamole/domain/entities/assistant_conversation_scope.dart';
import 'package:fantastic_guacamole/domain/entities/task.dart';
import 'package:fantastic_guacamole/engine/learning/neural_dump.dart';
import 'package:fantastic_guacamole/engine/si/si_engine_service.dart';
import 'package:fantastic_guacamole/state/services/si_engine_dependencies.dart';

class StateSiEngineService {
  StateSiEngineService(
    this._repository, {
    required this.dependencies,
    SIEngineService Function()? engineFactory,
  }) : _engineFactory = engineFactory ?? SIEngineService.new;

  final SiEngineRepository _repository;
  final SIEngineService Function() _engineFactory;
  final Map<AssistantConversationScope, SIEngineService> _engines =
      <AssistantConversationScope, SIEngineService>{};
  final SiEngineDependencies dependencies;

  SIEngineService _engineFor(AssistantConversationScope conversation) =>
      _engines.putIfAbsent(conversation, _engineFactory);

  Future<Map<String, dynamic>?> loadState({
    AssistantConversationScope conversation =
        AssistantConversationScope.primarySiConsole,
  }) => _repository.loadState(conversation);

  Future<void> saveState(
    Map<String, dynamic> state, {
    AssistantConversationScope conversation =
        AssistantConversationScope.primarySiConsole,
  }) => _repository.saveState(conversation, state);

  Future<Map<String, dynamic>?> exportState({
    AssistantConversationScope conversation =
        AssistantConversationScope.primarySiConsole,
  }) => _repository.exportState(conversation);

  Future<Map<String, dynamic>> exportAllStates() async {
    return <String, dynamic>{
      AssistantSurface.smartPlanner.storageId:
          await exportState(
            conversation: AssistantConversationScope.primarySmartPlanner,
          ) ??
          const <String, dynamic>{},
      AssistantSurface.siConsole.storageId:
          await exportState(
            conversation: AssistantConversationScope.primarySiConsole,
          ) ??
          const <String, dynamic>{},
    };
  }

  Future<void> clearMemory({
    AssistantConversationScope conversation =
        AssistantConversationScope.primarySiConsole,
  }) async {
    _engines.remove(conversation)?.clear();
    await _repository.clearState(conversation);
  }

  Future<void> clearAllMemory() async {
    for (final SIEngineService engine in _engines.values) {
      engine.clear();
    }
    _engines.clear();
    await Future.wait(<Future<void>>[
      _repository.clearState(AssistantConversationScope.primarySmartPlanner),
      _repository.clearState(AssistantConversationScope.primarySiConsole),
      _repository.clearLegacyState(),
    ]);
  }

  Future<SIFinalOutputBundle> handleUserInput(
    SIInputPacket input, {
    AssistantConversationScope conversation =
        AssistantConversationScope.primarySiConsole,
    List<NeuralEntry> history = const <NeuralEntry>[],
    Task? task,
    List<String> goals = const <String>[],
    String? previousMood,
  }) {
    return _engineFor(conversation).handleUserInput(
      input,
      history: history,
      task: task,
      goals: goals,
      previousMood: previousMood,
    );
  }

  Future<Map<String, dynamic>> generateResponse({
    AssistantConversationScope conversation =
        AssistantConversationScope.primarySiConsole,
    required String input,
    required String message,
    String emotion = 'balanced',
    double confidence = 0.5,
    String? taskId,
    Map<String, dynamic> context = const <String, dynamic>{},
  }) async {
    return _engineFor(conversation).generateResponse(
      input: input,
      message: message,
      emotion: emotion,
      confidence: confidence,
      taskId: taskId,
      context: context,
    );
  }

  Map<String, dynamic> updateMemory({
    AssistantConversationScope conversation =
        AssistantConversationScope.primarySiConsole,
    required Map<String, dynamic>? currentState,
    required Map<String, dynamic> memoryEvent,
  }) {
    return _engineFor(
      conversation,
    ).updateMemory(currentState: currentState, memoryEvent: memoryEvent);
  }

  bool validateOutput({
    AssistantConversationScope conversation =
        AssistantConversationScope.primarySiConsole,
    required String message,
    required double confidence,
    bool coherent = true,
    bool deduped = true,
    bool policyAccepted = true,
    bool grounded = true,
  }) {
    return _engineFor(conversation).validateOutput(
      message: message,
      confidence: confidence,
      coherent: coherent,
      deduped: deduped,
      policyAccepted: policyAccepted,
      grounded: grounded,
    );
  }
}
