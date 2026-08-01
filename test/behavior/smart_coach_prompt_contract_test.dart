import 'package:fantastic_guacamole/engine/assistant/chronospark_prompt_architecture.dart';
import 'package:fantastic_guacamole/engine/si/ai_personality.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Smart Coach prompt contract', () {
    test('keeps the policy structured and practical', () {
      final String policy = ChronoSparkPromptArchitecture.smartCoachPolicy();

      expect(policy, contains('Identify the user\'s intent category'));
      expect(policy, contains('Goal Detected'));
      expect(policy, contains('Coach Question'));
      expect(policy, contains('Always provide practical actions first'));
    });

    test('keeps the proxy prompt grounded in personality and context', () {
      final String prompt = ChronoSparkPromptArchitecture.proxySystemPrompt(
        personality: AIPersonality.coach,
        context: <String, dynamic>{
          'surface': 'si-console',
          'signals': <String>['tasks', 'goals'],
        },
      );

      expect(prompt, contains('ChronoSpark Smart Coach.'));
      expect(prompt, contains('Personality: coach.'));
      expect(prompt, contains('"surface":"si-console"'));
      expect(prompt, contains('"signals":["tasks","goals"]'));
    });
  });
}