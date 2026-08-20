import 'package:fantastic_guacamole/domain/entities/assistant_conversation_scope.dart';
import 'package:fantastic_guacamole/engine/assistant/assistant_interfaces.dart';
import 'package:fantastic_guacamole/engine/assistant/assistant_models.dart';

class DefaultAssistantContextBuilder implements AssistantContextBuilder {
  const DefaultAssistantContextBuilder();

  @override
  AssistantContext buildSmartPlannerContext({
    required String input,
    required AssistantIntent intent,
    required double energy,
    required String emotion,
    required List<String> memorySummaries,
    required List<String> timelineSummaries,
    required List<String> goalSummaries,
  }) {
    return AssistantContext(
      surface: AssistantSurface.smartPlanner,
      intent: intent,
      query: input,
      metadata: <String, Object?>{
        'energy': energy,
        'emotion': emotion,
        'memorySummaries': memorySummaries,
        'timelineSummaries': timelineSummaries,
        'goalSummaries': goalSummaries,
      },
    );
  }

  @override
  AssistantContext buildSIConsoleContext({
    required String input,
    required AssistantIntent intent,
    required List<String> matchedSurfaces,
    required List<String> memorySummaries,
    required List<String> timelineSummaries,
    required int taskCount,
    required int goalCount,
  }) {
    return AssistantContext(
      surface: AssistantSurface.siConsole,
      intent: intent,
      query: input,
      metadata: <String, Object?>{
        'matchedSurfaces': matchedSurfaces,
        'memorySummaries': memorySummaries,
        'timelineSummaries': timelineSummaries,
        'taskCount': taskCount,
        'goalCount': goalCount,
      },
    );
  }
}
