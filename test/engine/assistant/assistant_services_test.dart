import 'package:fantastic_guacamole/domain/entities/assistant_contracts.dart';
import 'package:fantastic_guacamole/domain/entities/assistant_conversation_scope.dart';
import 'package:fantastic_guacamole/engine/assistant/assistant_context_builder.dart';
import 'package:fantastic_guacamole/engine/assistant/assistant_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const DefaultAssistantContextBuilder contextBuilder =
      DefaultAssistantContextBuilder();

  test('builds assistant context payloads', () {
    final AssistantIntent intent = AssistantIntent(
      label: 'status_check',
      confidence: 0.9,
      surface: AssistantSurface.siConsole,
      group: 'si_console',
    );
    final AssistantContext context = contextBuilder.buildSIConsoleContext(
      input: 'status check',
      intent: intent,
      matchedSurfaces: const <String>['tasks', 'timeline'],
      memorySummaries: const <String>['recent memory'],
      timelineSummaries: const <String>['timeline event'],
      taskCount: 4,
      goalCount: 2,
    );

    expect(context.surface, AssistantSurface.siConsole);
    expect(context.metadata['taskCount'], 4);
    expect(context.metadata['goalCount'], 2);
    expect(context.metadata['matchedSurfaces'], contains('tasks'));
  });

  test('intent and context reject non-JSON metadata', () {
    expect(
      () => AssistantIntent(
        label: 'invalid',
        confidence: 0.5,
        surface: AssistantSurface.siConsole,
        group: 'si_console',
        metadata: <String, Object?>{'generatedAt': DateTime.now()},
      ),
      throwsA(isA<AssistantContractException>()),
    );
  });
}
