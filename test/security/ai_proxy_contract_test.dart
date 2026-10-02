import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final String proxy = File(
    'supabase/functions/ai-proxy/index.ts',
  ).readAsStringSync();
  final String client = File(
    'lib/data/services/ai/agents/chat_agent.dart',
  ).readAsStringSync();
  final String migration = File(
    'supabase/migrations/20260904022000_remove_ai_proxy_conversation_retention.sql',
  ).readAsStringSync();

  test('system authority is server-owned and request bodies are bounded', () {
    expect(proxy, contains('buildServerSystemPrompt'));
    expect(proxy, contains('request_too_large'));
    expect(proxy, isNot(contains('body.system')));
    expect(client, isNot(contains("'system': system")));
  });

  test(
    'provider output is safety-gated before bounded recovery storage',
    () {
      expect(proxy, contains('containsBlockedAssistantClaim(message)'));
      expect(proxy, contains('failureCode: "unsafe_provider_output"'));
      expect(proxy, contains('p_response_ttl: "15 minutes"'));
      expect(proxy, contains('Date.parse(row.response_expires_at) > Date.now()'));
      expect(proxy, contains('principal?.current_user_id !== userId'));
      expect(proxy, contains('payload.requestId !== requestId'));
      expect(migration, contains("request_key like 'ai-%'"));
      expect(migration, contains("response_payload = '{}'::jsonb"));
    },
  );
}
