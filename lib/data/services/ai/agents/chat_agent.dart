import 'dart:async';
import 'dart:convert';

import 'package:fantastic_guacamole/config/env.dart';
import 'package:fantastic_guacamole/core/network/retry_executor.dart';
import 'package:fantastic_guacamole/data/network/secure_endpoint.dart';
import 'package:fantastic_guacamole/data/services/ai/agents/ai_agent.dart';
import 'package:fantastic_guacamole/domain/entities/task.dart';
import 'package:fantastic_guacamole/engine/learning/learning_state.dart';
import 'package:fantastic_guacamole/engine/si/ai_personality.dart';
import 'package:fantastic_guacamole/engine/si/ai_response.dart';
import 'package:fantastic_guacamole/engine/si/models/si_state.dart';
import 'package:fantastic_guacamole/engine/si/si_ai_service.dart';
import 'package:http/http.dart' as http;

class AiProxyCreditsExhaustedException implements Exception {
  const AiProxyCreditsExhaustedException({required this.remainingCredits});

  final int remainingCredits;
}

class AiProxyUnavailableException implements Exception {
  const AiProxyUnavailableException(this.reason);

  final String reason;

  @override
  String toString() => 'AI service unavailable: $reason';
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

    final AIResponse? proxyResponse = await _tryProxy(
      prompt: prompt,
      history: history,
      context: context,
      personality: personality,
    );
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

    return <String, dynamic>{
      'agent': name,
      'mode': 'conversation',
      'prompt': prompt,
      'task': response.task?.toJson(),
      'message': response.message,
      'reasoning': response.reasoning,
      'emotion': response.emotion,
      'confidence': response.confidence,
      'response': response.message,
      'status': 'ready',
      'requestId': response.metadata['requestId'],
      'creditsCharged': response.metadata['creditsCharged'],
      'remainingCredits': response.metadata['remainingCredits'],
      'safety': response.metadata['safety'],
    };
  }

  Future<AIResponse?> _tryProxy({
    required String prompt,
    required List<Map<String, String>> history,
    required Map<String, dynamic> context,
    required AIPersonality personality,
  }) async {
    final Uri? endpoint = parseSecureHttpsEndpoint(Env.aiProxyEndpoint);
    if (endpoint == null || prompt.trim().isEmpty) {
      if (Env.isProduction && prompt.trim().isNotEmpty) {
        throw const AiProxyUnavailableException('invalid endpoint');
      }
      return null;
    }
    final String? accessToken = currentSupabaseAccessToken();
    if (Env.isProduction && accessToken == null) {
      throw const AiProxyUnavailableException('missing authenticated session');
    }
    final List<Map<String, String>> minimizedHistory = history
        .skip(history.length > 6 ? history.length - 6 : 0)
        .map(
          (Map<String, String> item) => <String, String>{
            'role': item['role'] ?? 'user',
            'content': _truncate(item['content'] ?? '', 1000),
          },
        )
        .toList(growable: false);
    final String requestId = context['requestId']?.toString() ?? '';

    try {
      final http.Response response = await runWithRetry<http.Response>(
        maxAttempts: 3,
        action: () async {
          final http.Response next = await http
              .post(
                endpoint,
                headers: <String, String>{
                  'Content-Type': 'application/json',
                  if (accessToken != null)
                    'Authorization': 'Bearer $accessToken',
                },
                body: jsonEncode(<String, dynamic>{
                  'prompt': prompt.trim(),
                  'history': minimizedHistory,
                  'personality': personality.name,
                  'requestId': requestId,
                }),
              )
              .timeout(const Duration(seconds: 15));
          if (next.statusCode == 408 ||
              next.statusCode == 429 ||
              next.statusCode >= 500) {
            throw http.ClientException(
              'Transient AI proxy failure: ${next.statusCode}',
              endpoint,
            );
          }
          return next;
        },
        retryIf: (Object error) {
          return error is TimeoutException || error is http.ClientException;
        },
      );
      if (response.statusCode == 402) {
        final Object? decoded = jsonDecode(response.body);
        final Map<dynamic, dynamic>? payload = decoded is Map ? decoded : null;
        throw AiProxyCreditsExhaustedException(
          remainingCredits:
              (payload?['remainingCredits'] as num?)?.toInt() ?? 0,
        );
      }
      if (response.statusCode != 200) {
        if (Env.isProduction) {
          throw AiProxyUnavailableException(
            'proxy returned HTTP ${response.statusCode}',
          );
        }
        return null;
      }

      final Object? decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        if (Env.isProduction) {
          throw const AiProxyUnavailableException('invalid proxy response');
        }
        return null;
      }
      final Map<String, dynamic> payload = decoded.map(
        (dynamic key, dynamic value) => MapEntry(key.toString(), value),
      );
      final String message =
          payload['message']?.toString().trim() ??
          payload['reply']?.toString().trim() ??
          '';
      if (message.isEmpty || _repeatsRecentAssistant(message, history)) {
        if (Env.isProduction) {
          throw const AiProxyUnavailableException('empty proxy response');
        }
        return null;
      }

      return AIResponse(
        message: message,
        reasoning:
            payload['reasoning']?.toString() ??
            'Generated from the current state and recent conversation.',
        emotion: payload['emotion']?.toString() ?? 'balanced',
        confidence: (payload['confidence'] as num?)?.toDouble() ?? 0.8,
        metadata: <String, dynamic>{
          'requestId': payload['requestId'],
          'creditsCharged': payload['creditsCharged'],
          'remainingCredits': payload['remainingCredits'],
          'safety': payload['safety'],
        },
      );
    } on AiProxyCreditsExhaustedException {
      rethrow;
    } on AiProxyUnavailableException {
      rethrow;
    } on TimeoutException {
      if (Env.isProduction) {
        throw const AiProxyUnavailableException('request timed out');
      }
      return null;
    } on Exception catch (error) {
      if (Env.isProduction) {
        throw AiProxyUnavailableException(error.runtimeType.toString());
      }
      return null;
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
