import 'dart:async';
import 'dart:convert';

import 'package:fantastic_guacamole/config/env.dart';
import 'package:fantastic_guacamole/data/network/secure_endpoint.dart';
import 'package:fantastic_guacamole/data/services/ai/agents/ai_agent.dart';
import 'package:fantastic_guacamole/domain/entities/task.dart';
import 'package:fantastic_guacamole/domain/policies/si_policy.dart';
import 'package:fantastic_guacamole/engine/learning/learning_state.dart';
import 'package:fantastic_guacamole/engine/si/ai_personality.dart';
import 'package:fantastic_guacamole/engine/si/ai_response.dart';
import 'package:fantastic_guacamole/engine/si/models/si_state.dart';
import 'package:fantastic_guacamole/engine/si/si_ai_service.dart';
import 'package:http/http.dart' as http;

/// Outcome of an attempt to reach the AI proxy.
///
/// Exists so callers can tell a real model response apart from a locally
/// generated one. Previously every failure collapsed to `null` and the local
/// engine's answer was surfaced as if the model had produced it.
enum AiProxyOutcome {
  /// The proxy returned a usable model response.
  model,

  /// The proxy was not attempted — not configured, empty prompt, or no auth
  /// token in a production build. No model response was ever expected.
  notAttempted,

  /// The proxy was attempted and did not yield a usable response.
  failed,

  /// The proxy replied, but the reply was withheld by the safety policy.
  withheld,
}

/// A proxy attempt and, when successful, its response.
class AiProxyAttempt {
  const AiProxyAttempt(this.outcome, [this.response]);

  final AiProxyOutcome outcome;
  final AIResponse? response;
}

class ChatAgent extends AiAgent {
  const ChatAgent({this.service});

  final SIAIService? service;

  @override
  String get name => 'chat';

  @override
  Future<Map<String, dynamic>> execute(Map<String, dynamic> request) async {
    final String prompt = request['prompt']?.toString() ?? '';
    final List<Task> tasks =
        (request['tasks'] as List<Task>?) ?? const <Task>[];
    final SIState? si = request['si'] as SIState?;
    final LearningState? learning = request['learning'] as LearningState?;
    final AIPersonality personality = request['personality'] is AIPersonality
        ? request['personality'] as AIPersonality
        : AIPersonality.coach;
    final Map<String, dynamic> context =
        request['context'] as Map<String, dynamic>? ??
        const <String, dynamic>{};
    final List<Map<String, String>> history = _readHistory(request['history']);

    final AiProxyAttempt attempt = await _tryProxy(
      prompt: prompt,
      history: history,
      context: context,
      personality: personality,
    );
    final AIResponse? proxyResponse = attempt.response;
    final AIResponse response =
        proxyResponse ??
        ((si != null && learning != null && prompt.trim().isNotEmpty)
            ? await (service ?? SIAIService()).handleInput(
                prompt,
                tasks: tasks,
                energy: si.energy,
                learning: learning,
                personality: personality,
                history: history,
                context: context,
              )
            : await (service ?? SIAIService()).generate(
                tasks: tasks,
                si: si ?? const SIState(),
                learning: learning ?? const LearningState(),
                personality: personality,
              ));

    // When the model was expected but did not deliver, say so. Presenting a
    // locally generated answer as a model response is the behaviour this
    // disclosure exists to prevent.
    final String disclosure = _degradedNotice(attempt.outcome);
    final String message = disclosure.isEmpty
        ? response.message
        : '${response.message}\n\n$disclosure';

    return <String, dynamic>{
      'agent': name,
      'mode': 'conversation',
      'prompt': prompt,
      'task': response.task?.toJson(),
      'message': message,
      'reasoning': response.reasoning,
      'emotion': response.emotion,
      'confidence': response.confidence,
      'response': message,
      'status': 'ready',
      // Machine-readable provenance for callers and diagnostics.
      'source': attempt.outcome.name,
      'modelBacked': attempt.outcome == AiProxyOutcome.model,
    };
  }

  /// User-visible disclosure for a response the model did not produce.
  ///
  /// Deliberately empty when the proxy was never configured — in that build
  /// the local engine is the intended engine, not a degraded substitute.
  static String _degradedNotice(AiProxyOutcome outcome) {
    switch (outcome) {
      case AiProxyOutcome.model:
      case AiProxyOutcome.notAttempted:
        return '';
      case AiProxyOutcome.failed:
        return 'Note: the assistant service could not be reached, so this '
            'reply was generated on-device from your current data.';
      case AiProxyOutcome.withheld:
        return 'Note: the assistant reply was withheld by ChronoSpark safety '
            'policy, so this reply was generated on-device from your current '
            'data.';
    }
  }

  Future<AiProxyAttempt> _tryProxy({
    required String prompt,
    required List<Map<String, String>> history,
    required Map<String, dynamic> context,
    required AIPersonality personality,
  }) async {
    final Uri? endpoint = parseSecureHttpsEndpoint(Env.aiProxyEndpoint);
    if (endpoint == null || prompt.trim().isEmpty) {
      return const AiProxyAttempt(AiProxyOutcome.notAttempted);
    }
    final String? accessToken = currentSupabaseAccessToken();
    if (Env.isProduction && accessToken == null) {
      return const AiProxyAttempt(AiProxyOutcome.notAttempted);
    }
    final Map<String, dynamic> minimizedContext = _minimizeProxyContext(
      context,
    );
    final List<Map<String, String>> minimizedHistory = history
        .skip(history.length > 6 ? history.length - 6 : 0)
        .map(
          (Map<String, String> item) => <String, String>{
            'role': item['role'] ?? 'user',
            'content': _truncate(item['content'] ?? '', 1000),
          },
        )
        .toList(growable: false);

    try {
      final http.Response response = await http
          .post(
            endpoint,
            headers: <String, String>{
              'Content-Type': 'application/json',
              if (accessToken != null) 'Authorization': 'Bearer $accessToken',
            },
            body: jsonEncode(<String, dynamic>{
              'prompt': prompt.trim(),
              'history': minimizedHistory,
              'system': _systemPrompt(personality, minimizedContext),
            }),
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        return const AiProxyAttempt(AiProxyOutcome.failed);
      }

      final Object? decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        return const AiProxyAttempt(AiProxyOutcome.failed);
      }
      final Map<String, dynamic> payload = decoded.map(
        (dynamic key, dynamic value) => MapEntry(key.toString(), value),
      );
      final String message =
          payload['message']?.toString().trim() ??
          payload['reply']?.toString().trim() ??
          '';
      if (message.isEmpty || _repeatsRecentAssistant(message, history)) {
        return const AiProxyAttempt(AiProxyOutcome.failed);
      }
      final String reasoning =
          payload['reasoning']?.toString() ??
          'Generated from the current state and recent conversation.';
      // Model output is held to the same standard as a SiDecisionEntity.
      // Without this, generated prose bypassed the unsupported-claim list
      // entirely — SiPolicy only ever saw decisions.
      if (SiPolicy.containsUnsupportedClaim('$message $reasoning')) {
        return const AiProxyAttempt(AiProxyOutcome.withheld);
      }

      return AiProxyAttempt(
        AiProxyOutcome.model,
        AIResponse(
          message: message,
          reasoning: reasoning,
          emotion: payload['emotion']?.toString() ?? 'balanced',
          confidence: (payload['confidence'] as num?)?.toDouble() ?? 0.8,
        ),
      );
    } on TimeoutException {
      return const AiProxyAttempt(AiProxyOutcome.failed);
    } on Object {
      // `on Object`: a malformed payload can produce a TypeError, which is an
      // Error and not an Exception, and previously escaped this method.
      return const AiProxyAttempt(AiProxyOutcome.failed);
    }
  }

  List<Map<String, String>> _readHistory(Object? value) {
    if (value is! List) {
      return const <Map<String, String>>[];
    }
    return value
        .whereType<Map<dynamic, dynamic>>()
        .map(
          (Map<dynamic, dynamic> item) => <String, String>{
            'role': item['role']?.toString() ?? 'user',
            'content': item['content']?.toString() ?? '',
          },
        )
        .where(
          (Map<String, String> item) =>
              item['content']?.trim().isNotEmpty ?? false,
        )
        .toList(growable: false);
  }

  String _systemPrompt(
    AIPersonality personality,
    Map<String, dynamic> context,
  ) {
    return 'You are ChronoSpark Smart Coach. Be concise, practical, and '
        'specific to the user context. Answer the newest message directly. '
        'Use recent conversation history, but do not repeat earlier wording '
        'or generic motivational slogans. Give one useful insight and one '
        'clear next action. Never claim to be a therapist or diagnose. '
        'Personality: ${personality.name}. Context: ${jsonEncode(context)}';
  }

  Map<String, dynamic> _minimizeProxyContext(Map<String, dynamic> context) {
    final String surface = context['querySurface']?.toString() ?? '';
    final Object? rawSnapshot = context['featureSnapshot'];
    final Map<String, dynamic> featureSnapshot =
        rawSnapshot is Map<String, dynamic>
        ? rawSnapshot
        : const <String, dynamic>{};
    final Object? rawGrounded = context['grounded'];
    final Map<String, dynamic> grounded = rawGrounded is Map<String, dynamic>
        ? rawGrounded
        : const <String, dynamic>{};
    final List<String> memories =
        (grounded['memorySummaries'] as List<dynamic>? ?? const <dynamic>[])
            .take(4)
            .map((dynamic value) => _truncate(value.toString(), 240))
            .toList(growable: false);

    return <String, dynamic>{
      for (final String key in <String>[
        'mode',
        'intent',
        'querySurface',
        'responseContract',
        'energy',
        'emotion',
        'fatigue',
        'completedToday',
      ])
        if (context[key] != null) key: context[key],
      if (surface.isNotEmpty && featureSnapshot[surface] != null)
        'featureSnapshot': <String, dynamic>{surface: featureSnapshot[surface]},
      'grounded': <String, dynamic>{
        'taskCount': grounded['taskCount'] ?? 0,
        'memoryCount': memories.length,
        if (memories.isNotEmpty) 'memorySummaries': memories,
      },
    };
  }

  String _truncate(String value, int maxLength) {
    final String trimmed = value.trim();
    return trimmed.length <= maxLength
        ? trimmed
        : trimmed.substring(0, maxLength);
  }

  bool _repeatsRecentAssistant(
    String candidate,
    List<Map<String, String>> history,
  ) {
    final String normalizedCandidate = _normalize(candidate);
    return history.reversed
        .where((Map<String, String> item) => item['role'] == 'assistant')
        .take(3)
        .any((Map<String, String> item) {
          final String previous = _normalize(item['content'] ?? '');
          return previous == normalizedCandidate ||
              _wordSimilarity(previous, normalizedCandidate) >= 0.82;
        });
  }

  String _normalize(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
  }

  double _wordSimilarity(String a, String b) {
    Set<String> words(String value) => value
        .split(RegExp(r'\s+'))
        .where((String word) => word.length > 2)
        .toSet();
    final Set<String> left = words(a);
    final Set<String> right = words(b);
    if (left.isEmpty || right.isEmpty) {
      return 0;
    }
    return left.intersection(right).length / left.union(right).length;
  }
}
