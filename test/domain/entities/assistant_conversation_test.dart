import 'dart:async';
import 'package:fantastic_guacamole/domain/entities/assistant_conversation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ConversationPacket packet({
    Map<String, Object?>? context,
    List<Map<String, String>> history = const [],
  }) => ConversationPacket(
    surface: ConversationSurface.planner,
    accountScope: 'account:test',
    prompt: 'What time should I go to the store?',
    history: history,
    context:
        context ??
        {
          'tasks': [
            {'title': 'Grocery list'},
          ],
        },
    requestId: 'synthetic-request',
  );
  Map<String, dynamic> quoteData() => {
    'credits': 4,
    'digest': 'test-digest',
    'proof': 'test-proof',
    'policy': 'test-policy',
    'expiresAt': DateTime.now()
        .add(const Duration(minutes: 5))
        .millisecondsSinceEpoch,
  };
  Map<String, dynamic> answerData() => {
    'requestId': 'synthetic-request',
    'message': 'What time window are you free to go shopping?',
    'model': 'fixture-model',
    'creditsCharged': 4,
    'remainingCredits': 20,
  };

  test(
    'quote and execute preserve the reviewed payload and request identity',
    () async {
      final context = <String, Object?>{
        'tasks': [
          {'title': 'Grocery list'},
        ],
      };
      final request = packet(context: context);
      final sent = <Map<String, dynamic>>[];
      final service = ConversationService(
        authorize: (_) {},
        transport: (body) async {
          sent.add(body);
          return (
            status: 200,
            data: body['quoteOnly'] == true
                ? {'requestId': request.requestId, 'quote': quoteData()}
                : answerData(),
          );
        },
      );
      final quote = await service.quote(request);
      context['tasks'] = [
        {'title': 'Changed after review'},
      ];
      final answer = await service.execute(quote);
      expect(answer.text, contains('time window'));
      expect(sent[1]['prompt'], sent[0]['prompt']);
      expect(sent[1]['context'], sent[0]['context']);
      expect(sent[1]['requestId'], sent[0]['requestId']);
      expect(sent[1]['quote'], quote.data);
    },
  );

  test(
    'conversation includes both sides, retaining only the six latest turns',
    () {
      final history = [
        for (var i = 0; i < 10; i++)
          {'role': i.isEven ? 'user' : 'assistant', 'content': 'Turn $i'},
      ];
      final body = packet(history: history).toJson();
      expect(body['history'], history.sublist(4));
    },
  );

  for (final status in [402, 403, 409, 429, 500, 502]) {
    test(
      'HTTP $status is a failure, never a fabricated local answer',
      () async {
        final request = packet();
        final service = ConversationService(
          authorize: (_) {},
          transport: (_) async =>
              (status: status, data: {'error': 'synthetic_failure'}),
        );
        await expectLater(
          service.execute(
            ConversationQuote(packet: request, data: quoteData()),
          ),
          throwsA(isA<ConversationFailure>()),
        );
      },
    );
  }

  test(
    'large context keeps the attached first record and reports omissions',
    () {
      final original = <String, Object?>{
        'tasks': [
          for (var i = 0; i < 12; i++)
            {'id': 'task-$i', 'description': 'Details ' * 200},
        ],
      };
      final body = packet(context: original).toJson();
      final context = body['context'] as Map;
      expect(((context['tasks'] as List).first as Map)['id'], 'task-0');
      expect(context['omittedRecordCount'], greaterThan(0));
      expect((original['tasks'] as List), hasLength(12));
    },
  );

  test(
    'long conversation messages retain the latest correction and mark clipping',
    () {
      final body = packet(
        history: [
          {
            'role': 'assistant',
            'content': '${'Earlier advice ' * 400}Latest correction',
          },
        ],
      ).toJson();
      final message =
          ((body['history'] as List).single as Map)['content'] as String;
      expect(message.length, lessThanOrEqualTo(2500));
      expect(message, endsWith('Latest correction'));
      expect((body['context'] as Map)['historyClipped'], true);
    },
  );

  test('expired quote never reaches transport', () async {
    var calls = 0;
    final service = ConversationService(
      authorize: (_) {},
      transport: (_) async {
        calls++;
        return (status: 200, data: answerData());
      },
    );
    final quote = ConversationQuote(
      packet: packet(),
      data: {
        ...quoteData(),
        'expiresAt': DateTime.now()
            .subtract(const Duration(seconds: 1))
            .millisecondsSinceEpoch,
      },
    );
    await expectLater(
      service.execute(quote),
      throwsA(isA<ConversationFailure>()),
    );
    expect(calls, 0);
  });

  test(
    'retry sends the same request and quote, including after lost transport',
    () async {
      final sent = <Map<String, dynamic>>[];
      final quote = ConversationQuote(packet: packet(), data: quoteData());
      final service = ConversationService(
        authorize: (_) {},
        transport: (body) async {
          sent.add(body);
          if (sent.length == 1) throw TimeoutException('synthetic');
          return (status: 409, data: {'error': 'request_completed'});
        },
      );
      await expectLater(
        service.execute(quote),
        throwsA(isA<TimeoutException>()),
      );
      await expectLater(
        service.execute(quote),
        throwsA(isA<ConversationFailure>()),
      );
      expect(sent[1], sent[0]);
    },
  );

  test('revoked authorization stops the request before transport', () async {
    var calls = 0;
    final service = ConversationService(
      authorize: (_) =>
          throw const ConversationFailure('authorization_changed'),
      transport: (_) async {
        calls++;
        return (status: 200, data: answerData());
      },
    );
    await expectLater(
      service.execute(ConversationQuote(packet: packet(), data: quoteData())),
      throwsA(isA<ConversationFailure>()),
    );
    expect(calls, 0);
  });

  test('account change during transport withholds the late response', () async {
    var valid = true;
    final service = ConversationService(
      authorize: (_) {
        if (!valid) throw const ConversationFailure('authorization_changed');
      },
      transport: (_) async {
        valid = false;
        return (status: 200, data: answerData());
      },
    );
    await expectLater(
      service.execute(ConversationQuote(packet: packet(), data: quoteData())),
      throwsA(isA<ConversationFailure>()),
    );
  });

  test(
    'server must confirm the quoted charge and matching response identity',
    () async {
      final service = ConversationService(
        authorize: (_) {},
        transport: (_) async =>
            (status: 200, data: {...answerData(), 'creditsCharged': 5}),
      );
      await expectLater(
        service.execute(ConversationQuote(packet: packet(), data: quoteData())),
        throwsA(isA<ConversationFailure>()),
      );
    },
  );
}
