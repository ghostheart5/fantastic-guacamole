import 'dart:async';
import 'dart:convert';
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

  test('only the explicitly attached note enters the note safety input', () {
    final request = packet(
      context: {
        'tasks': [
          {'title': 'A historical crisis reference'},
        ],
        'explicitlyAttachedNote': {
          'title': 'Current note',
          'body': 'I need help right now.',
        },
      },
    );
    expect(
      request.attachedNoteSafetyText,
      'Current note I need help right now.',
    );
    expect(request.attachedNoteSafetyText, isNot(contains('historical')));
    expect(packet().attachedNoteSafetyText, isEmpty);
  });

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

  test(
    'a stored pending request rebuilds the exact signed body or nothing',
    () {
      final original = PendingConversationRequest(
        quote: ConversationQuote(
          packet: packet(
            history: [
              {'role': 'user', 'content': 'Earlier question ñ'},
              {'role': 'assistant', 'content': 'Earlier answer'},
            ],
            context: {
              'tasks': [
                {'title': 'Grocery list', 'energy': 1.0},
              ],
            },
          ),
          data: quoteData(),
        ),
        savedAt: DateTime.now(),
      );
      final json = jsonDecode(jsonEncode(original.toJson()));
      final restored = PendingConversationRequest.fromJson(
        ConversationSurface.planner,
        json,
      );
      expect(
        jsonEncode({
          ...restored.quote.packet.toJson(),
          'quote': restored.quote.data,
        }),
        jsonEncode({
          ...original.quote.packet.toJson(),
          'quote': original.quote.data,
        }),
      );
      expect(restored.prompt, 'What time should I go to the store?');

      final body = (json as Map)['body'] as String;
      for (final changed in [
        body.replaceFirst('"prompt":"', '"prompt": "'),
        body.replaceFirst('store?', 'shop?').replaceFirst('"planner"', '"x"'),
        body.replaceFirst('"maxTokens":1024', '"maxTokens":2048'),
        '$body ',
        'not json',
      ]) {
        expect(
          () => PendingConversationRequest.fromJson(
            ConversationSurface.planner,
            {...json, 'body': changed},
          ),
          throwsA(anything),
          reason: changed,
        );
      }
      // The stored surface must be the one the body was signed for.
      expect(
        () => PendingConversationRequest.fromJson(ConversationSurface.si, json),
        throwsA(isA<ConversationFailure>()),
      );
    },
  );

  test('a pending request is collectable only within the quote lifetime', () {
    final saved = DateTime.utc(2026, 11, 23, 12);
    PendingConversationRequest at(DateTime quoteExpiry) =>
        PendingConversationRequest(
          quote: ConversationQuote(
            packet: packet(),
            data: {
              ...quoteData(),
              'expiresAt': quoteExpiry.millisecondsSinceEpoch,
            },
          ),
          savedAt: saved,
        );
    final normal = at(saved.add(const Duration(minutes: 4)));
    expect(normal.collectBefore, saved.add(const Duration(minutes: 4)));
    expect(normal.isExpired(saved.add(const Duration(minutes: 3))), isFalse);
    expect(normal.isExpired(saved.add(const Duration(minutes: 4))), isTrue);
    // A device clock behind the server never extends the window past 5 min.
    final skewed = at(saved.add(const Duration(minutes: 30)));
    expect(
      skewed.collectBefore,
      saved.add(PendingConversationRequest.lifetime),
    );
  });

  test('a reply receipt counts what the sent packet carried and what the '
      'server confirmed', () {
    final sent = ConversationPacket(
      surface: ConversationSurface.planner,
      accountScope: 'account:test',
      prompt: 'What should I do next?',
      history: const [
        {'role': 'user', 'content': 'Earlier question'},
        {'role': 'assistant', 'content': 'Earlier answer'},
      ],
      context: {
        'tasks': [
          {'id': 'a', 'title': 'One'},
          {'id': 'b', 'title': 'Two'},
        ],
        'goals': [
          {'id': 'g', 'title': 'Goal'},
        ],
        'milestones': const <Object?>[],
        'timeline': [
          {'title': 'Event'},
        ],
        'explicitlyAttachedNote': {'title': 'Note', 'body': 'Body'},
        'reportedEnergy': 0.5,
      },
      requestId: 'synthetic-request',
    );
    const answer = ConversationAnswer(
      text: 'Reply',
      model: 'fixture-model',
      credits: 5,
      remainingCredits: 15,
      requestId: 'synthetic-request',
    );
    final receipt = ConversationReplyReceipt.fromReply(sent, answer);
    expect(receipt.tasks, 2);
    expect(receipt.goals, 1);
    expect(receipt.milestones, 0);
    expect(receipt.schedule, 1);
    expect(receipt.note, isTrue);
    expect(receipt.energy, isTrue);
    expect(receipt.emotion, isFalse);
    expect(receipt.earlierMessages, 2);
    expect(receipt.creditsCharged, 5);
    expect(receipt.remainingCredits, 15);

    // Stored and read back unchanged; anything else is no receipt at all.
    final restored = ConversationReplyReceipt.decode(receipt.encode())!;
    expect(restored.toJson(), receipt.toJson());
    expect(ConversationReplyReceipt.decode(null), isNull);
    expect(ConversationReplyReceipt.decode('not json'), isNull);
    for (final damaged in <Map<String, Object?>>[
      {...receipt.toJson(), 'version': 2},
      {...receipt.toJson(), 'tasks': -1},
      {...receipt.toJson(), 'tasks': '2'},
      {...receipt.toJson(), 'creditsCharged': 0},
      {...receipt.toJson(), 'remainingCredits': -3},
      {...receipt.toJson(), 'note': 'yes'},
      {...receipt.toJson(), 'extra': 1},
    ]) {
      expect(ConversationReplyReceipt.fromJson(damaged), isNull);
    }
  });

  test('a declined charge carries the balance the server reported', () async {
    final service = ConversationService(
      authorize: (_) {},
      transport: (body) async => body['quoteOnly'] == true
          ? (
              status: 200,
              data: <String, dynamic>{
                'requestId': 'synthetic-request',
                'quote': quoteData(),
              },
            )
          : (
              status: 402,
              data: <String, dynamic>{
                'requestId': 'synthetic-request',
                'error': 'insufficient_credits',
                'remainingCredits': 3,
              },
            ),
    );
    final quote = await service.quote(packet());
    await expectLater(
      service.execute(quote),
      throwsA(
        isA<ConversationFailure>()
            .having((f) => f.code, 'code', 'insufficient_credits')
            .having((f) => f.remainingCredits, 'remainingCredits', 3),
      ),
    );
  });
}
