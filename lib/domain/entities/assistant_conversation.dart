// CHRONOSPARK-CLASS: SHIPPING | Feature: Consented assistant conversations
import 'dart:convert';
import 'dart:math';

enum ConversationSurface { planner, si }

/// The price, in credits, of one AI chat message as the server prices it
/// today: every request reaches MAX_CUSTOMER_CREDITS_PER_QUESTION in
/// supabase/functions/_shared/ai_credit_quote.ts. The send button shows it,
/// and tapping send confirms it. The signed quote is still compared with it;
/// a different price is asked about before anything is charged.
const conversationMessageCredits = 5;

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

  /// Rebuilds a confirmed request from its stored bytes. Anything that is not
  /// exactly what [ConversationPacket.new] would have produced is rejected, so
  /// a changed request can never be sent under the original signed id.
  ConversationPacket.restore({
    required this.surface,
    required this.accountScope,
    required this.requestId,
    required String body,
  }) : _bodyJson = body {
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw const ConversationFailure('invalid_request');
    }
    final prompt = decoded is Map ? decoded['prompt'] : null;
    final history = decoded is Map ? decoded['history'] : null;
    final context = decoded is Map ? decoded['context'] : null;
    if (decoded is! Map<String, dynamic> ||
        jsonEncode(decoded) != body ||
        body.length > 30000 ||
        accountScope.isEmpty ||
        requestId.isEmpty ||
        requestId.length > 128 ||
        decoded.containsKey('requestId') ||
        prompt is! String ||
        prompt.isEmpty ||
        prompt != prompt.trim() ||
        prompt.length > 8000 ||
        history is! List ||
        history.length > 6 ||
        history.any(
          (turn) =>
              turn is! Map ||
              !{'user', 'assistant'}.contains(turn['role']) ||
              turn['content'] is! String,
        ) ||
        context is! Map ||
        context['surface'] != surface.name ||
        decoded['personality'] !=
            (surface == ConversationSurface.planner
                ? 'planner'
                : 'strategist') ||
        decoded['maxTokens'] != 1024 ||
        decoded['allowExternalAi'] != true) {
      throw const ConversationFailure('invalid_request');
    }
  }

  final ConversationSurface surface;
  final String accountScope;
  final String requestId;
  final String _bodyJson;

  /// The exact reviewed bytes, without the request id, for local recovery.
  String get serializedBody => _bodyJson;
  Map<String, dynamic> toJson() => {
    ...jsonDecode(_bodyJson) as Map<String, dynamic>,
    'requestId': requestId,
  };
  String get preview =>
      const JsonEncoder.withIndent('  ').convert(toJson()['context']);

  /// Only the note deliberately attached to this request can change its
  /// emotional-safety route. Other records may describe past or unrelated work.
  String get attachedNoteSafetyText {
    final context = toJson()['context'] as Map;
    final note = context['explicitlyAttachedNote'];
    if (note is! Map) return '';
    return [note['title'], note['body']].whereType<String>().join(' ').trim();
  }
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

/// A confirmed paid request that may still be running when its screen closes.
///
/// It is kept in the account's Chat store only until its reply is shown or it
/// can no longer be collected. The ai-proxy rejects a quote after its signed
/// `expiresAt`, at most 5 minutes after it was issued
/// (supabase/functions/_shared/ai_credit_quote.ts), before it looks up the
/// 15 minute reply cache; so the quote, not the cache, bounds recovery.
final class PendingConversationRequest {
  PendingConversationRequest({required this.quote, required DateTime savedAt})
    : savedAt = savedAt.toUtc();

  /// Throws [FormatException] or [ConversationFailure] for anything that does
  /// not rebuild the stored request exactly.
  factory PendingConversationRequest.fromJson(
    ConversationSurface surface,
    Object? json,
  ) {
    if (json is! Map ||
        json['version'] != 1 ||
        json['requestId'] is! String ||
        json['accountScope'] is! String ||
        json['body'] is! String ||
        json['quote'] is! Map ||
        json['savedAt'] is! int) {
      throw const FormatException('pending_request');
    }
    final packet = ConversationPacket.restore(
      surface: surface,
      accountScope: json['accountScope'] as String,
      requestId: json['requestId'] as String,
      body: json['body'] as String,
    );
    return PendingConversationRequest(
      quote: ConversationQuote(
        packet: packet,
        data: Map<String, dynamic>.from(json['quote'] as Map),
      ),
      savedAt: DateTime.fromMillisecondsSinceEpoch(
        json['savedAt'] as int,
        isUtc: true,
      ),
    );
  }

  /// The longest lifetime the server gives a signed credit quote.
  static const lifetime = Duration(minutes: 5);

  final ConversationQuote quote;
  final DateTime savedAt;
  String get requestId => quote.packet.requestId;
  ConversationSurface get surface => quote.packet.surface;
  String get prompt => quote.packet.toJson()['prompt'] as String;

  DateTime get collectBefore {
    final cap = savedAt.add(lifetime);
    return quote.expiresAt.isBefore(cap) ? quote.expiresAt : cap;
  }

  bool isExpired(DateTime now) => !collectBefore.isAfter(now.toUtc());

  Map<String, Object?> toJson() => {
    'version': 1,
    'requestId': requestId,
    'accountScope': quote.packet.accountScope,
    'body': quote.packet.serializedBody,
    'quote': quote.data,
    'savedAt': savedAt.millisecondsSinceEpoch,
  };
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

/// What one AI reply used and cost, shown under it and kept with it in the
/// account's Chat store. The counts come from the packet that was sent for
/// the reply; the credits from the server's confirmed reply. Nothing else is
/// recorded: no record content, titles or identifiers.
final class ConversationReplyReceipt {
  const ConversationReplyReceipt({
    this.tasks = 0,
    this.goals = 0,
    this.milestones = 0,
    this.schedule = 0,
    this.note = false,
    this.energy = false,
    this.emotion = false,
    this.earlierMessages = 0,
    required this.creditsCharged,
    required this.remainingCredits,
  });

  /// Counted from the exact packet that produced [answer], so a recovered
  /// reply shows what its own stored request carried.
  factory ConversationReplyReceipt.fromReply(
    ConversationPacket packet,
    ConversationAnswer answer,
  ) {
    final body = packet.toJson();
    final context = body['context'] as Map;
    int count(String key) =>
        context[key] is List ? (context[key] as List).length : 0;
    return ConversationReplyReceipt(
      tasks: count('tasks'),
      goals: count('goals'),
      milestones: count('milestones'),
      schedule: count('timeline'),
      note: context['explicitlyAttachedNote'] is Map,
      energy: context['reportedEnergy'] is num,
      emotion: context['reportedEmotion'] is String,
      earlierMessages: body['history'] is List
          ? (body['history'] as List).length
          : 0,
      creditsCharged: answer.credits,
      remainingCredits: answer.remainingCredits,
    );
  }

  /// The key a reply's receipt is kept under in a conversation turn.
  static const turnKey = 'receipt';

  final int tasks;
  final int goals;
  final int milestones;
  final int schedule;
  final bool note;
  final bool energy;
  final bool emotion;
  final int earlierMessages;
  final int creditsCharged;
  final int remainingCredits;

  Map<String, Object?> toJson() => {
    'version': 1,
    'tasks': tasks,
    'goals': goals,
    'milestones': milestones,
    'schedule': schedule,
    'note': note,
    'energy': energy,
    'emotion': emotion,
    'earlierMessages': earlierMessages,
    'creditsCharged': creditsCharged,
    'remainingCredits': remainingCredits,
  };

  String encode() => jsonEncode(toJson());

  /// Null for anything that is not exactly a receipt this version writes, so
  /// a damaged or unknown one simply shows no footer.
  static ConversationReplyReceipt? fromJson(Object? json) {
    if (json is! Map || json.length != 11 || json['version'] != 1) return null;
    int? count(String key, {int min = 0, int max = 1000}) {
      final value = json[key];
      return value is int && value >= min && value <= max ? value : null;
    }

    final tasks = count('tasks');
    final goals = count('goals');
    final milestones = count('milestones');
    final schedule = count('schedule');
    final earlier = count('earlierMessages');
    final charged = count('creditsCharged', min: 1, max: 100);
    final remaining = count('remainingCredits', max: 1 << 31);
    final note = json['note'];
    final energy = json['energy'];
    final emotion = json['emotion'];
    if (tasks == null ||
        goals == null ||
        milestones == null ||
        schedule == null ||
        earlier == null ||
        charged == null ||
        remaining == null ||
        note is! bool ||
        energy is! bool ||
        emotion is! bool) {
      return null;
    }
    return ConversationReplyReceipt(
      tasks: tasks,
      goals: goals,
      milestones: milestones,
      schedule: schedule,
      note: note,
      energy: energy,
      emotion: emotion,
      earlierMessages: earlier,
      creditsCharged: charged,
      remainingCredits: remaining,
    );
  }

  static ConversationReplyReceipt? decode(String? encoded) {
    if (encoded == null) return null;
    try {
      return fromJson(jsonDecode(encoded));
    } on FormatException {
      return null;
    }
  }
}

final class ConversationFailure implements Exception {
  const ConversationFailure(this.code, {this.remainingCredits});
  final String code;

  /// The balance the server reported with this answer, when it sent one.
  final int? remainingCredits;
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
      final balance = response.data['remainingCredits'];
      throw ConversationFailure(
        _error(response.data),
        remainingCredits: balance is int && balance >= 0 ? balance : null,
      );
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
