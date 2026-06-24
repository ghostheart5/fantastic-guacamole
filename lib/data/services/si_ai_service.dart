import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/state/app_state.dart';
import '../../core/utils/cancel_token.dart';

class SiAiService {
  SiAiService({http.Client? client, String? endpoint, String? apiKey, String? model})
    : _client = client ?? http.Client(),
      _endpoint =
          endpoint ??
          const String.fromEnvironment(
            'CHRONOSPARK_AI_ENDPOINT',
            defaultValue: 'https://api.openai.com/v1/chat/completions',
          ),
      _apiKey = apiKey ?? const String.fromEnvironment('CHRONOSPARK_AI_KEY'),
      _model =
          model ??
          const String.fromEnvironment('CHRONOSPARK_AI_MODEL', defaultValue: 'gpt-4o-mini');

  final http.Client _client;
  final String _endpoint;
  final String _apiKey;
  final String _model;

  bool get isConfigured => _apiKey.trim().isNotEmpty;

  /// Generates an AI response for [prompt] given the current [decision] context.
  ///
  /// Pass a [cancelToken] to allow the caller to abandon the request mid-flight.
  /// Returns `null` when the service is not configured, the request fails, or
  /// the operation has been cancelled.
  Future<String?> generateResponse({
    required String prompt,
    required Decision decision,
    CancelToken? cancelToken,
  }) async {
    if (cancelToken?.isCancelled ?? false) {
      return null;
    }

    if (!isConfigured) {
      return null;
    }

    final Map<String, dynamic> body = <String, dynamic>{
      'model': _model,
      'messages': <Map<String, String>>[
        const <String, String>{
          'role': 'system',
          'content': 'You are ChronoSpark SI. Reply concise, operational, and action-oriented.',
        },
        <String, String>{
          'role': 'user',
          'content':
              'Current system note: ${decision.systemNote}. Primary: ${decision.primaryDecision}. Secondary: ${decision.secondaryAction}. User input: $prompt',
        },
      ],
      'temperature': 0.4,
    };

    if (cancelToken?.isCancelled ?? false) {
      return null;
    }

    final http.Response response = await _client.post(
      Uri.parse(_endpoint),
      headers: <String, String>{
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
      },
      body: jsonEncode(body),
    );

    if (cancelToken?.isCancelled ?? false) {
      return null;
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return null;
    }

    final Map<String, dynamic> decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final List<dynamic> choices = decoded['choices'] as List<dynamic>? ?? const <dynamic>[];
    if (choices.isEmpty) {
      return null;
    }

    final Map<String, dynamic> first = choices.first as Map<String, dynamic>;
    final Map<String, dynamic> message =
        first['message'] as Map<String, dynamic>? ?? const <String, dynamic>{};
    final String content = (message['content'] as String?)?.trim() ?? '';
    return content.isEmpty ? null : content;
  }
}
