import 'package:fantastic_guacamole/domain/policies/crisis_detection_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Crisis detection policy contract', () {
    test('detects direct and euphemistic self-harm phrasing', () {
      const List<String> highRiskPrompts = <String>[
        'I want to die',
        'I do not want to live anymore',
        "I can't go on",
        'I am ending it all tonight',
        'Sometimes I want to disappear forever',
      ];

      for (final String prompt in highRiskPrompts) {
        expect(
          CrisisDetectionPolicy.detects(prompt),
          isTrue,
          reason: 'Expected crisis detection for: $prompt',
        );
      }
    });

    test('does not trigger for non-crisis planning language', () {
      const List<String> safePrompts = <String>[
        'I want to end my work day at 6pm',
        'Help me reduce stress and plan tomorrow',
        'I am tired and need better sleep habits',
      ];

      for (final String prompt in safePrompts) {
        expect(
          CrisisDetectionPolicy.detects(prompt),
          isFalse,
          reason: 'Unexpected crisis detection for: $prompt',
        );
      }
    });
  });
}
