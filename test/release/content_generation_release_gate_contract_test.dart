import 'package:fantastic_guacamole/core/debug/content_generation_release_gate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Content generation release gate contract', () {
    test('passes for structured response within latency budget', () {
      final result = ContentGenerationReleaseGate.evaluateRequest(
        surface: 'smart_coach',
        durationMs: 900,
        structured: true,
      );

      expect(result.passed, isTrue);
      expect(result.reason, 'ok');
    });

    test('fails for latency budget breach', () {
      final result = ContentGenerationReleaseGate.evaluateRequest(
        surface: 'si_console',
        durationMs: ContentGenerationReleaseGate.maxSingleRequestLatencyMs + 1,
        structured: true,
      );

      expect(result.passed, isFalse);
      expect(result.reason, 'latency_budget_exceeded');
    });

    test('fails for structure contract miss', () {
      final result = ContentGenerationReleaseGate.evaluateRequest(
        surface: 'smart_coach_follow_up',
        durationMs: 1000,
        structured: false,
      );

      expect(result.passed, isFalse);
      expect(result.reason, 'structure_contract_miss');
    });
  });
}
