// CHRONOSPARK-CLASS: SHIPPING | Feature: Consented assistant conversations
import 'dart:convert';
import 'dart:math';

enum ConversationSurface { planner, si }

/// An immutable, reviewable request. Quote and execution serialize the same
/// bytes even if the user edits records while the confirmation dialog is open.
final class ConversationPacket {
  ConversationPacket({
    required this.surface,
    required this.accountScope,
    required String prompt,
    required List<Map<String, String>> history,
    required Map<String, Object?> context,
    String? requestId,
  }) : requestId =
           requestId ??
           'conversation-${List.generate(16, (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0')).join()}',
       _bodyJson = jsonEncode({
         'prompt': prompt.trim(),
         'history': _boundedHistory(history),
         'personality': surface == ConversationSurface.planner
             ? 'planner'
             : 'strategist',
         'context': {
           ..._boundedContext(context),
           'surface': surface.name,
           if (history.any((t) => (t['content']?.length ?? 0) > 2500))
             'historyClipped': true,
         },
         'maxTokens': 1024,
         'allowExternalAi': true,
       }) {
    if (prompt.trim().isEmpty ||
        prompt.length > 8000 ||
        accountScope.isEmpty ||
        _bodyJson.length > 30000 ||
        history.any((turn) => !{'user', 'assistant'}.contains(turn['role']))) {
      throw const ConversationFailure('invalid_request');
    }
  }
  final ConversationSurface surface;
  final String accountScope;
  final String requestId;
  final String _bodyJson;
  Map<String, dynamic> toJson() => {
    ...jsonDecode(_bodyJson) as Map<String, dynamic>,
    'requestId': requestId,
  };
  String get preview =>
      const JsonEncoder.withIndent('  ').convert(toJson()['context']);
}

List<Map<String, String>> _boundedHistory(
  List<Map<String, String>> history,
) => history.skip(history.length > 6 ? history.length - 6 : 0).map((turn) {
  final content = turn['content'] ?? '';
  return {
    'role': turn['role'] ?? 'user',
    'content': content.length <= 2500
        ? content
        : '${content.substring(0, 1400)}\n[Earlier message shortened]\n${content.substring(content.length - 1000)}',
  };
}).toList();

Map<String, Object?> _boundedContext(Map<String, Object?> input) {
  final context = Map<String, Object?>.from(
    jsonDecode(jsonEncode(input)) as Map,
  );
  while (jsonEncode(context).length > 10000) {
    final candidates = ['tasks', 'goals', 'milestones', 'timeline']
        .where(
          (key) => context[key] is List && (context[key] as List).length > 1,
        )
        .toList();
    if (candidates.isEmpty) {
      throw const ConversationFailure('context_too_large');
    }
    candidates.sort(
      (a, b) => jsonEncode(
        context[b],
      ).length.compareTo(jsonEncode(context[a]).length),
    );
    (context[candidates.first] as List).removeLast();
    context['omittedRecordCount'] =
        ((context['omittedRecordCount'] as int?) ?? 0) + 1;
  }
  return context;
}

final class ConversationQuote {
  ConversationQuote({required this.packet, required Map<String, dynamic> data})
    : _json = jsonEncode(data) {
    if (data['credits'] is! int ||
        (data['credits'] as int) < 1 ||
        (data['credits'] as int) > 100 ||
        data['expiresAt'] is! int ||
        data['proof'] is! String ||
        data['digest'] is! String ||
        data['policy'] is! String) {
      throw const ConversationFailure('invalid_quote');
    }
  }
  final ConversationPacket packet;
  final String _json;
  Map<String, dynamic> get data => jsonDecode(_json) as Map<String, dynamic>;
  int get credits => data['credits'] as int;
  DateTime get expiresAt => DateTime.fromMillisecondsSinceEpoch(
    data['expiresAt'] as int,
    isUtc: true,
  );
}

final class ConversationAnswer {
  const ConversationAnswer({
    required this.text,
    required this.model,
    required this.credits,
    required this.remainingCredits,
    required this.requestId,
  });
  final String text;
  final String model;
  final int credits;
  final int remainingCredits;
  final String requestId;
}

final class ConversationFailure implements Exception {
  const ConversationFailure(this.code);
  final String code;
  @override
  String toString() => 'ConversationFailure($code)';
}

typedef ConversationTransport =
    Future<({int status, Map<String, dynamic> data})> Function(
      Map<String, dynamic> body,
    );

/// Never substitutes local text for a failed model request.
final class ConversationService {
  const ConversationService({required this.transport, required this.authorize});
  final ConversationTransport transport;
  final void Function(ConversationPacket) authorize;

  Future<ConversationQuote> quote(ConversationPacket packet) async {
    authorize(packet);
    final response = await transport({...packet.toJson(), 'quoteOnly': true});
    authorize(packet);
    if (response.status != 200) {
      throw ConversationFailure(_error(response.data));
    }
    if (response.data['requestId'] != packet.requestId ||
        response.data['quote'] is! Map) {
      throw const ConversationFailure('invalid_quote');
    }
    return ConversationQuote(
      packet: packet,
      data: Map<String, dynamic>.from(response.data['quote'] as Map),
    );
  }

  Future<ConversationAnswer> execute(ConversationQuote quote) async {
    authorize(quote.packet);
    if (!quote.expiresAt.isAfter(DateTime.now().toUtc())) {
      throw const ConversationFailure('quote_expired');
    }
    final response = await transport({
      ...quote.packet.toJson(),
      'quote': quote.data,
    });
    authorize(quote.packet);
    if (response.status != 200) {
      throw ConversationFailure(_error(response.data));
    }
    final data = response.data;
    if (data['requestId'] != quote.packet.requestId ||
        data['creditsCharged'] != quote.credits ||
        data['remainingCredits'] is! int ||
        (data['remainingCredits'] as int) < 0 ||
        data['message'] is! String ||
        (data['message'] as String).trim().isEmpty ||
        (data['message'] as String).length > 12000 ||
        data['model'] is! String) {
      throw const ConversationFailure('unconfirmed_result');
    }
    return ConversationAnswer(
      text: (data['message'] as String).trim(),
      model: data['model'] as String,
      credits: quote.credits,
      remainingCredits: data['remainingCredits'] as int,
      requestId: quote.packet.requestId,
    );
  }

  String _error(Map<String, dynamic> data) =>
      data['error'] is String ? data['error'] as String : 'service_unavailable';
}
