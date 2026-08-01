import 'package:fantastic_guacamole/engine/assistant/assistant_detection_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Assistant intent mixed-query contract', () {
    const DefaultAssistantIntentDetector detector =
        DefaultAssistantIntentDetector();

    test('smart coach favors stress_support for mixed stress and planning prompt', () {
      final intent = detector.detect(
        input: 'I am stressed and overwhelmed, help me plan one next task.',
        surface: 'smart_coach',
      );

      expect(intent.label, 'stress_support');
      expect(intent.confidence, greaterThan(0.8));
    });

    test('si console favors timeline query for schedule-risk mixed prompt', () {
      final intent = detector.detect(
        input: 'I have overdue tasks and deadline risk, what should I do next?',
        surface: 'si_console',
      );

      expect(intent.label, 'timeline_query');
      expect(intent.metadata['group'], 'si_console');
    });

    test('si console favors task query when next-action wording dominates', () {
      final intent = detector.detect(
        input: 'What next action should I take on my tasks right now?',
        surface: 'si_console',
      );

      expect(intent.label, 'task_query');
    });
  });
}
