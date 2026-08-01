import 'package:fantastic_guacamole/core/debug/app_analytics.dart';

class ContentGenerationReleaseGateResult {
  const ContentGenerationReleaseGateResult({
    required this.passed,
    required this.reason,
  });

  final bool passed;
  final String reason;
}

class ContentGenerationReleaseGate {
  const ContentGenerationReleaseGate._();

  // Phase D baseline request budget; this can be tightened after field data.
  static const int maxSingleRequestLatencyMs = 25000;

  static ContentGenerationReleaseGateResult evaluateRequest({
    required String surface,
    required int durationMs,
    required bool structured,
  }) {
    if (durationMs > maxSingleRequestLatencyMs) {
      final ContentGenerationReleaseGateResult result =
          const ContentGenerationReleaseGateResult(
            passed: false,
            reason: 'latency_budget_exceeded',
          );
      _trackBreach(
        surface: surface,
        reason: result.reason,
        durationMs: durationMs,
      );
      return result;
    }

    if (!structured) {
      final ContentGenerationReleaseGateResult result =
          const ContentGenerationReleaseGateResult(
            passed: false,
            reason: 'structure_contract_miss',
          );
      _trackBreach(
        surface: surface,
        reason: result.reason,
        durationMs: durationMs,
      );
      return result;
    }

    return const ContentGenerationReleaseGateResult(passed: true, reason: 'ok');
  }

  static void _trackBreach({
    required String surface,
    required String reason,
    required int durationMs,
  }) {
    AppAnalytics.track(
      'content_release_gate_breach',
      params: <String, Object?>{
        'surface': surface,
        'reason': reason,
        'duration_ms': durationMs,
      },
    );
  }
}
