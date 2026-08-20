import 'package:fantastic_guacamole/domain/entities/assistant_contracts.dart';
import 'package:fantastic_guacamole/domain/entities/assistant_conversation_scope.dart';
import 'package:fantastic_guacamole/engine/assistant/assistant_context_builder.dart';
import 'package:fantastic_guacamole/engine/assistant/assistant_detection_service.dart';
import 'package:fantastic_guacamole/engine/assistant/assistant_models.dart';
import 'package:fantastic_guacamole/engine/assistant/assistant_response_templates.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const DefaultAssistantIntentDetector detector =
      DefaultAssistantIntentDetector();
  const DefaultAssistantContextBuilder contextBuilder =
      DefaultAssistantContextBuilder();

  test('detects Smart Planner use cases', () {
    expect(
      detector
          .detect(
            input: 'I want to gain weight and build muscle',
            surface: AssistantSurface.smartPlanner,
          )
          .label,
      'weight_gain',
    );
    expect(
      detector
          .detect(
            input: 'I am burned out and overloaded',
            surface: AssistantSurface.smartPlanner,
          )
          .label,
      'stress_support',
    );
    expect(
      detector
          .detect(
            input: 'I need help with my career path',
            surface: AssistantSurface.smartPlanner,
          )
          .label,
      'life',
    );
  });

  test('builds assistant context payloads', () {
    final AssistantIntent intent = detector.detect(
      input: 'status check',
      surface: AssistantSurface.siConsole,
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

  test('renders SI analysis template', () {
    final String analysis = AssistantResponseTemplates.siAnalysis(
      query: 'What should I do next?',
      category: 'Goal Query',
      goalsCount: 2,
      openTasks: 5,
      overdue: 1,
      priorityTask: 'Finish sprint planning',
      impact: 'High',
      timelineEffect: 'Keeps core goals on measurable milestones.',
      nextActions: const <String>[
        'Plan the next step',
        'Check timeline risks',
        'Create next task',
      ],
      confidence: 88,
    );

    expect(analysis, contains('🧠 SI ANALYSIS'));
    expect(analysis, contains('Goal Query'));
    expect(analysis, contains('Next Actions'));
    expect(analysis, contains('Evidence Strength'));
    expect(analysis, contains('Strong'));
    expect(analysis, isNot(contains('88%')));
  });
}
