import 'dart:convert';

import 'package:fantastic_guacamole/data/services/ai/planner_explanation_service.dart';
import 'package:fantastic_guacamole/domain/entities/planner_explanation_contract.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'quote and execute use one bounded first-party request identity',
    () async {
      final List<http.Request> requests = <http.Request>[];
      final MockClient client = MockClient((http.Request request) async {
        requests.add(request);
        final Map<String, Object?> body = _decode(request.body);
        return switch (body['operation']) {
          'quote' => http.Response(
            jsonEncode(_quoteJson(body['requestId']! as String)),
            200,
          ),
          'execute' => http.Response(
            jsonEncode(
              _resultJson(
                requestId: body['requestId']! as String,
                responseDigest: body['responseDigest']! as String,
              ),
            ),
            200,
          ),
          _ => http.Response('{}', 400),
        };
      });
      final HttpPlannerExplanationService service =
          HttpPlannerExplanationService(
            endpoint: Uri.parse(
              'https://project.supabase.co/functions/v1/planner-explanation',
            ),
            apiKey: 'publishable-test-key',
            accessToken: () async => 'user-jwt',
            client: client,
            requestIdFactory: () => 'planner-request-fixed',
          );
      final PlannerExplanationPacket packet = _packet();

      final PlannerExplanationQuote quote = await service.quote(packet);
      final PlannerExplanationResult result = await service.execute(
        packet: packet,
        quote: quote,
      );

      expect(requests, hasLength(2));
      expect(quote.requestId, 'planner-request-fixed');
      expect(result.requestId, quote.requestId);
      expect(result.responseDigest, packet.responseDigest);
      for (final http.Request request in requests) {
        expect(request.url.path, '/functions/v1/planner-explanation');
        expect(request.headers['authorization'], 'Bearer user-jwt');
        expect(request.headers['apikey'], 'publishable-test-key');
      }
      final Map<String, Object?> quoteBody = _decode(requests.first.body);
      expect(quoteBody.keys, <String>{
        'schemaVersion',
        'operation',
        'surface',
        'requestId',
        'responseDigest',
        'clauses',
      });
      final Map<String, Object?> executeBody = _decode(requests.last.body);
      expect(executeBody.keys, <String>{
        'schemaVersion',
        'operation',
        'surface',
        'requestId',
        'responseDigest',
        'clauses',
        'quoteId',
        'expectedCredits',
        'disclosureVersion',
        'consentAccepted',
      });
      for (final String forbidden in <String>[
        'systemPrompt',
        'system',
        'model',
        'messages',
        'tools',
        'actions',
        'accountId',
        'userId',
      ]) {
        expect(quoteBody, isNot(contains(forbidden)));
        expect(executeBody, isNot(contains(forbidden)));
      }
    },
  );

  test('authentication failure sends no request', () async {
    int requests = 0;
    final HttpPlannerExplanationService service = HttpPlannerExplanationService(
      endpoint: Uri.parse(
        'https://project.supabase.co/functions/v1/planner-explanation',
      ),
      apiKey: 'publishable-test-key',
      accessToken: () async => null,
      client: MockClient((http.Request request) async {
        requests += 1;
        return http.Response('{}', 200);
      }),
    );

    await expectLater(
      () => service.quote(_packet()),
      throwsA(
        isA<PlannerExplanationServiceException>().having(
          (PlannerExplanationServiceException error) => error.code,
          'code',
          'authentication_required',
        ),
      ),
    );
    expect(requests, 0);
  });

  test('malformed JSON fails closed', () async {
    final HttpPlannerExplanationService service = HttpPlannerExplanationService(
      endpoint: Uri.parse(
        'https://project.supabase.co/functions/v1/planner-explanation',
      ),
      apiKey: 'publishable-test-key',
      accessToken: () async => 'user-jwt',
      client: MockClient(
        (http.Request request) async => http.Response('not-json', 200),
      ),
    );

    await expectLater(
      () => service.quote(_packet()),
      throwsA(
        isA<PlannerExplanationServiceException>().having(
          (PlannerExplanationServiceException error) => error.code,
          'code',
          'invalid_response_json',
        ),
      ),
    );
  });

  test('HTTP rejection exposes only bounded error code', () async {
    final HttpPlannerExplanationService service = HttpPlannerExplanationService(
      endpoint: Uri.parse(
        'https://project.supabase.co/functions/v1/planner-explanation',
      ),
      apiKey: 'publishable-test-key',
      accessToken: () async => 'user-jwt',
      client: MockClient(
        (http.Request request) async => http.Response(
          jsonEncode(<String, Object?>{
            'error': 'safety_blocked',
            'detail': 'private upstream content must not escape',
          }),
          422,
        ),
      ),
    );

    await expectLater(
      () => service.quote(_packet()),
      throwsA(
        isA<PlannerExplanationServiceException>()
            .having(
              (PlannerExplanationServiceException error) => error.code,
              'code',
              'safety_blocked',
            )
            .having(
              (PlannerExplanationServiceException error) => error.message,
              'message',
              isNot(contains('private upstream content')),
            ),
      ),
    );
  });

  test('disabled port performs no external work', () async {
    const DisabledPlannerExplanationPort port =
        DisabledPlannerExplanationPort();

    await expectLater(
      () => port.quote(_packet()),
      throwsA(
        isA<PlannerExplanationServiceException>().having(
          (PlannerExplanationServiceException error) => error.code,
          'code',
          'external_ai_disabled',
        ),
      ),
    );
  });

  test('constructor rejects non-HTTPS and non-canonical paths', () {
    for (final String endpoint in <String>[
      'http://project.supabase.co/functions/v1/planner-explanation',
      'https://project.supabase.co/functions/v1/ai-proxy',
    ]) {
      expect(
        () => HttpPlannerExplanationService(
          endpoint: Uri.parse(endpoint),
          apiKey: 'publishable-test-key',
          accessToken: () async => 'user-jwt',
          client: MockClient(
            (http.Request request) async => http.Response('{}', 200),
          ),
        ),
        throwsA(isA<PlannerExplanationServiceException>()),
      );
    }
  });
}

PlannerExplanationPacket _packet() => PlannerExplanationPacket(
  clauses: <PlannerExplanationClause>[
    PlannerExplanationClause(id: 'focus', text: 'Choose one bounded action.'),
    PlannerExplanationClause(id: 'tradeoff', text: 'Narrow but reversible.'),
  ],
);

Map<String, Object?> _quoteJson(String requestId) => <String, Object?>{
  'schemaVersion': plannerExplanationSchemaVersion,
  'operation': 'quote',
  'surface': plannerExplanationSurface,
  'requestId': requestId,
  'quoteId': 'quote-fixed',
  'expectedCredits': 2,
  'provider': 'Anthropic',
  'modelLabel': 'server-selected-model',
  'promptVersion': 'planner-explanation-v1',
  'responseSchemaVersion': plannerExplanationSchemaVersion,
  'disclosureVersion': plannerExplanationDisclosureVersion,
  'transmittedDataCategories': <String>['visible plan clauses'],
  'replayWindowSeconds': 240,
  'providerRetentionStatus': 'verified_external_gate',
  'expiresAt': DateTime.now()
      .toUtc()
      .add(const Duration(minutes: 4))
      .toIso8601String(),
};

Map<String, Object?> _resultJson({
  required String requestId,
  required String responseDigest,
}) => <String, Object?>{
  'schemaVersion': plannerExplanationSchemaVersion,
  'operation': 'execute',
  'surface': plannerExplanationSurface,
  'requestId': requestId,
  'status': 'completed',
  'responseDigest': responseDigest,
  'explanation': 'The visible action is narrow and reversible.',
  'sourceClauseIds': <String>['focus', 'tradeoff'],
  'provider': 'Anthropic',
  'modelLabel': 'server-selected-model',
  'promptVersion': 'planner-explanation-v1',
  'responseSchemaVersion': plannerExplanationSchemaVersion,
  'expectedCredits': 2,
  'creditsCharged': 2,
  'remainingCredits': 8,
  'contentExpiresAt': DateTime.now()
      .toUtc()
      .add(const Duration(minutes: 5))
      .toIso8601String(),
  'replayState': 'fresh',
};

Map<String, Object?> _decode(String body) {
  return (jsonDecode(body) as Map<Object?, Object?>).map(
    (Object? key, Object? value) => MapEntry(key.toString(), value),
  );
}
