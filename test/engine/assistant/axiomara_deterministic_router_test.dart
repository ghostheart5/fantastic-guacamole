import 'package:fantastic_guacamole/domain/assistant/axiomara_router_contract.dart';
import 'package:fantastic_guacamole/engine/assistant/axiomara_deterministic_router.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const router = AxiomaraDeterministicRouter();

  test('simple retrieval stays local and free', () async {
    final result = await router.route(
      accountScopeId: 'account-a',
      input: 'Show my tasks',
      externalAiAllowed: true,
    );
    expect(result.route, AxiomaraRoute.local);
    expect(result.requiresCredits, isFalse);
  });

  test('priority decisions stay in SI', () async {
    final result = await router.route(
      accountScopeId: 'account-a',
      input: 'What should I do next?',
      externalAiAllowed: true,
    );
    expect(result.route, AxiomaraRoute.si);
    expect(result.externalAiUsed, isFalse);
  });

  test('grounded reflective reasoning selects hybrid', () async {
    final result = await router.route(
      accountScopeId: 'account-a',
      input: 'Help me figure out why I keep falling behind based on my tasks',
      externalAiAllowed: true,
    );
    expect(result.route, AxiomaraRoute.hybrid);
    expect(result.requiresCredits, isTrue);
  });

  test('external AI opt-out always prevents Claude routes', () async {
    final result = await router.route(
      accountScopeId: 'account-a',
      input: 'Help me think through a complicated situation',
      externalAiAllowed: false,
    );
    expect(result.route, AxiomaraRoute.si);
    expect(result.externalAiUsed, isFalse);
  });
}
