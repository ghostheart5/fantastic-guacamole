import 'package:fantastic_guacamole/domain/entities/assistant_context.dart';
import 'package:fantastic_guacamole/domain/ports/i_assistant_context_builder.dart';

/// CHRONOSPARK-CLASS: SHIPPING | Feature: SI Console
///
/// Domain entry point for schema-valid SI Console context assembly.
class AssembleSiContext {
  const AssembleSiContext(this._builder);

  final IAssistantContextBuilder _builder;

  AssistantContext call({
    required String input,
    required AssistantIntent intent,
    required List<String> matchedSurfaces,
    required List<String> memorySummaries,
    required List<String> timelineSummaries,
    required int taskCount,
    required int goalCount,
  }) {
    return _builder.buildSIConsoleContext(
      input: input,
      intent: intent,
      matchedSurfaces: matchedSurfaces,
      memorySummaries: memorySummaries,
      timelineSummaries: timelineSummaries,
      taskCount: taskCount,
      goalCount: goalCount,
    );
  }
}
