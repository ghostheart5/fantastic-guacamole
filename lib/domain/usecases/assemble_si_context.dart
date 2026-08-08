import 'package:fantastic_guacamole/engine/assistant/assistant_interfaces.dart';
import 'package:fantastic_guacamole/engine/assistant/assistant_models.dart';

/// CHRONOSPARK-CLASS: SHIPPING | Feature: SI Console
///
/// Domain entry point for SI Console context assembly. The map shape stays in
/// [AssistantContextBuilder]; this exists so controllers depend on a use case
/// rather than constructing engine context directly.
class AssembleSiContext {
  const AssembleSiContext(this._builder);

  final AssistantContextBuilder _builder;

  Map<String, dynamic> call({
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
