import 'package:fantastic_guacamole/domain/entities/assistant_context.dart';

/// CHRONOSPARK-CLASS: SHIPPING | Feature: Assistant shared contracts
abstract interface class IAssistantContextBuilder {
  AssistantContext buildSIConsoleContext({
    required String input,
    required AssistantIntent intent,
    required List<String> matchedSurfaces,
    required List<String> memorySummaries,
    required List<String> timelineSummaries,
    required int taskCount,
    required int goalCount,
  });
}
