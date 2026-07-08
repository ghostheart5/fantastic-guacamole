import 'package:fantastic_guacamole/engine/assistant/assistant_context_builder.dart';
import 'package:fantastic_guacamole/engine/assistant/assistant_detection_service.dart';
import 'package:fantastic_guacamole/engine/assistant/assistant_models.dart';
import 'package:fantastic_guacamole/engine/assistant/assistant_response_templates.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const DefaultAssistantIntentDetector detector = DefaultAssistantIntentDetector();
  const DefaultAssistantContextBuilder contextBuilder = DefaultAssistantContextBuilder();

  test('detects smart coach usecases', () {
    expect(
      detector
          .detect(input: 'I want to gain weight and build muscle', surface: 'smart_coach')
          .label,
      'weight_gain',
    );
    expect(
      detector.detect(input: 'I am burned out and overloaded', surface: 'smart_coach').label,
      'stress_support',
    );
    expect(
      detector.detect(input: 'I need help with my career path', surface: 'smart_coach').label,
      'life',
    );
  });

  test('builds assistant context payloads', () {
    final AssistantIntent intent = detector.detect(input: 'status check', surface: 'si_console');
    final Map<String, dynamic> context = contextBuilder.buildSIConsoleContext(
      input: 'status check',
      intent: intent,
      matchedSurfaces: const <String>['tasks', 'timeline'],
      memorySummaries: const <String>['recent memory'],
      timelineSummaries: const <String>['timeline event'],
      taskCount: 4,
      goalCount: 2,
    );

    expect(context['surface'], 'si_console');
    expect(context['taskCount'], 4);
    expect(context['goalCount'], 2);
    expect(context['matchedSurfaces'], contains('tasks'));
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
      nextActions: const <String>['Plan the next step', 'Check timeline risks', 'Create next task'],
      confidence: 88,
    );

    expect(analysis, contains('🧠 SI ANALYSIS'));
    expect(analysis, contains('Goal Query'));
    expect(analysis, contains('Next Actions'));
    expect(analysis, contains('88%'));
  });
}
