import 'package:fantastic_guacamole/data/services/ai/agents/chat_agent.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('proxy body carries the stable assistant request id', () {
    final Map<String, dynamic> body = buildAiProxyRequestBody(
      prompt: 'Plan the next step',
      history: const <Map<String, String>>[],
      system: 'system policy',
      requestId: 'ai-account-console-1770000000000-1',
    );

    expect(body['requestId'], 'ai-account-console-1770000000000-1');
    expect(body['allowExternalAi'], isTrue);
  });

  test('server 402 preserves authoritative remaining credits', () {
    final AiProxyAttempt? attempt = aiProxyFailureFromPayload(
      statusCode: 402,
      payload: const <String, dynamic>{
        'requestId': 'ai-account-console-1770000000000-1',
        'remainingCredits': 0,
        'error': 'insufficient_credits',
      },
      requestId: 'fallback-request-id',
    );

    expect(attempt?.outcome, AiProxyOutcome.creditsExhausted);
    expect(attempt?.remainingCredits, 0);
    expect(attempt?.requestId, 'ai-account-console-1770000000000-1');
  });

  test('nonbilling server failures stay distinct from exhausted credits', () {
    final AiProxyAttempt? attempt = aiProxyFailureFromPayload(
      statusCode: 503,
      payload: const <String, dynamic>{'error': 'backend_not_configured'},
      requestId: 'ai-account-console-1770000000000-1',
    );

    expect(attempt?.outcome, AiProxyOutcome.failed);
    expect(attempt?.remainingCredits, isNull);
  });
}
