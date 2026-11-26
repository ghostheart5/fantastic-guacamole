import 'dart:io';

import 'package:fantastic_guacamole/domain/entities/assistant_conversation.dart';
import 'package:flutter_test/flutter_test.dart';

/// The send button shows [conversationMessageCredits]. The signed quote stays
/// the charge (a different one is asked about first), but the button must
/// show what the deployed pricing produces for every request.
void main() {
  test('the price on the send button is the price every request is quoted', () {
    final source = File(
      'supabase/functions/_shared/ai_credit_quote.ts',
    ).readAsStringSync();
    int constant(String name) => int.parse(
      RegExp('export const $name = (\\d+);').firstMatch(source)!.group(1)!,
    );
    final cap = constant('MAX_CUSTOMER_CREDITS_PER_QUESTION');
    final perCredit = constant('CUSTOMER_QUOTE_MICROUSD_PER_CREDIT');
    final maxTokens = constant('MAX_PROVIDER_OUTPUT_TOKENS');
    expect(cap, conversationMessageCredits);
    // The formula the server uses, (bytes + 1024) * 3 + max_tokens * 15,
    // already reaches the cap for an empty request.
    expect(source, contains('return (bytes + 1024) * 3 + Number(max) * 15;'));
    final smallest = ((0 + 1024) * 3 + maxTokens * 15) / perCredit;
    expect(smallest.ceil(), greaterThanOrEqualTo(cap));
  });
}
