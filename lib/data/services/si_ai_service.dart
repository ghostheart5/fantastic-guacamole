import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../core/state/app_state.dart';
import '../../core/utils/retry.dart';
import '../../core/security/certificate_pinning_service.dart';
import 'package:http/io_client.dart';

class SiAiService {
  SiAiService({
    http.Client? client,
    String? endpoint,
    String? apiKey,
    String? model,
    bool enableCertificatePinning = true,
  })
    : _client = client ?? _createHttpClientWithPinning(enableCertificatePinning),
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

  Future<String?> generateResponse({required String prompt, required Decision decision}) async {
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

    final Uri endpoint = Uri.parse(_endpoint);
    final http.Response response = await retry<http.Response>(
      () async {
        final http.Response response = await _client
            .post(
              endpoint,
              headers: <String, String>{
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $_apiKey',
              },
              body: jsonEncode(body),
            )
            .timeout(const Duration(seconds: 10));

        if (response.statusCode == 429 || response.statusCode >= 500) {
          throw http.ClientException('Transient AI failure (${response.statusCode})', endpoint);
        }

        return response;
      },
      maxAttempts: 3,
      shouldRetry: (Object error, StackTrace stackTrace) =>
          error is TimeoutException || error is SocketException || error is http.ClientException,
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return null;
    }

    final Map<String, dynamic> decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final List<dynamic> choices = decoded['choices'] as List<dynamic>? ?? const <dynamic>[];
    if (choices.isEmpty) {
      return null;
    }

    try {
      final Map<String, dynamic> first = choices.first as Map<String, dynamic>;
      final Map<String, dynamic> message =
          first['message'] as Map<String, dynamic>? ?? const <String, dynamic>{};
      final String content = (message['content'] as String?)?.trim() ?? '';
      return content.isEmpty ? null : content;
    } catch (e) {
      // Malformed response structure
      return null;
    }
  }

  /// Create HTTP client with certificate pinning for OpenAI API
  static http.Client _createHttpClientWithPinning(bool enablePinning) {
    if (!enablePinning) {
      return http.Client();
    }

    try {
      final pinnedClient = CertificatePinningService.createPinnedHttpClient(
        certHash: CertificatePinningService.openaiApiCertHash,
      );
      return IOClient(pinnedClient);
    } catch (e) {
      // Fallback to non-pinned client if pinning fails
      return http.Client();
    }
  }
}
