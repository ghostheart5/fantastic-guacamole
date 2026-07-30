import 'package:fantastic_guacamole/engine/assistant/assistant_interfaces.dart';
import 'package:fantastic_guacamole/engine/assistant/assistant_models.dart';

class DefaultAssistantContextBuilder implements AssistantContextBuilder {
  const DefaultAssistantContextBuilder();

  @override
  Map<String, dynamic> buildSmartCoachContext({
    required String input,
    required AssistantIntent intent,
    required double energy,
    required String emotion,
    required List<String> memorySummaries,
    required List<String> timelineSummaries,
    required List<String> goalSummaries,
  }) {
    return <String, dynamic>{
      'surface': 'smart_coach',
      'intent': intent.toJson(),
      'query': input,
      'energy': energy,
      'emotion': emotion,
      'memorySummaries': memorySummaries,
      'timelineSummaries': timelineSummaries,
      'goalSummaries': goalSummaries,
    };
  }

  @override
  Map<String, dynamic> buildSIConsoleContext({
    required String input,
    required AssistantIntent intent,
    required List<String> matchedSurfaces,
    required List<String> memorySummaries,
    required List<String> timelineSummaries,
    required int taskCount,
    required int goalCount,
  }) {
    return <String, dynamic>{
      'surface': 'si_console',
      'intent': intent.toJson(),
      'query': input,
      'matchedSurfaces': matchedSurfaces,
      'memorySummaries': memorySummaries,
      'timelineSummaries': timelineSummaries,
      'taskCount': taskCount,
      'goalCount': goalCount,
    };
  }
}
