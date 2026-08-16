import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AI proxy resilience contract', () {
    late String source;

    setUpAll(() {
      source = File(
        'lib/data/services/ai/agents/chat_agent.dart',
      ).readAsStringSync();
    });

    test('uses bounded retry for transient proxy failures', () {
      expect(source, contains('runWithRetry<http.Response>('));
      expect(source, contains('maxAttempts: 3'));
      expect(
        source,
        contains('Transient AI proxy failure: \${next.statusCode}'),
      );
      expect(
        source,
        contains('TimeoutException || error is http.ClientException'),
      );
    });

    test('enforces request timeout and graceful fallback', () {
      expect(source, contains('.timeout(const Duration(seconds: 15))'));
      expect(source, contains('} on TimeoutException {'));
      expect(source, contains('} on Exception catch (error) {'));
      expect(source, contains('return null;'));
    });
  });
}
