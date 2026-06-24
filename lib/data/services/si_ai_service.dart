import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/state/app_state.dart';
import 'operation_cancellation.dart';

typedef AccessTokenProvider = Future<String?> Function();
const String _authorizationScheme = 'Bearer';

class SiAiService {
  SiAiService({
    http.Client? client,
    String? endpoint,
    String? apiKey,
    String? model,
    AccessTokenProvider? tokenProvider,
    AccessTokenProvider? tokenRefresher,
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null,
       _endpoint =
           endpoint ??
           const String.fromEnvironment(
             'CHRONOSPARK_AI_ENDPOINT',
             defaultValue: 'https://api.openai.com/v1/chat/completions',
           ),
       _apiKey = apiKey ?? const String.fromEnvironment('CHRONOSPARK_AI_KEY'),
       _model =
           model ??
           const String.fromEnvironment('CHRONOSPARK_AI_MODEL', defaultValue: 'gpt-4o-mini'),
       _tokenProvider = tokenProvider,
       _tokenRefresher = tokenRefresher;

  final http.Client _client;
  final bool _ownsClient;
  final String _endpoint;
  final String _apiKey;
  final String _model;
  final AccessTokenProvider? _tokenProvider;
  final AccessTokenProvider? _tokenRefresher;
  String? _refreshedToken;
  bool _isDisposed = false;

  bool get isConfigured => _apiKey.trim().isNotEmpty;

  Future<String?> generateResponse({
    required String prompt,
    required Decision decision,
    CancellationToken? cancellationToken,
  }) async {
    if (_isDisposed) {
      return null;
    }

    cancellationToken.throwIfCancelled();

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

    String? token = await _readToken(cancellationToken: cancellationToken);
    if (token == null || token.trim().isEmpty) {
      return null;
    }

    http.Response response = await _post(
      body: body,
      bearerToken: token,
      cancellationToken: cancellationToken,
    );

    if (response.statusCode == 401) {
      final bool refreshed = await _refreshToken(cancellationToken: cancellationToken);
      if (refreshed) {
        token = await _readToken(cancellationToken: cancellationToken);
        if (token != null && token.trim().isNotEmpty) {
          response = await _post(
            body: body,
            bearerToken: token,
            cancellationToken: cancellationToken,
          );
        }
      }
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return null;
    }

    cancellationToken.throwIfCancelled();

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

  Future<String?> _readToken({CancellationToken? cancellationToken}) async {
    cancellationToken.throwIfCancelled();

    final String refreshedToken = (_refreshedToken ?? '').trim();
    if (refreshedToken.isNotEmpty) {
      return refreshedToken;
    }

    if (_tokenProvider != null) {
      final String provided = (await _tokenProvider.call() ?? '').trim();
      cancellationToken.throwIfCancelled();
      if (provided.isNotEmpty) {
        return provided;
      }
    }

    final String key = _apiKey.trim();
    return key.isEmpty ? null : key;
  }

  Future<bool> _refreshToken({CancellationToken? cancellationToken}) async {
    if (_tokenRefresher == null) {
      return false;
    }

    cancellationToken.throwIfCancelled();
    final String refreshed = (await _tokenRefresher.call() ?? '').trim();
    cancellationToken.throwIfCancelled();
    if (refreshed.isEmpty) {
      return false;
    }
    _refreshedToken = refreshed;
    return true;
  }

  Future<http.Response> _post({
    required Map<String, dynamic> body,
    required String bearerToken,
    CancellationToken? cancellationToken,
  }) async {
    if (_isDisposed) {
      throw OperationCancelledException('Operation cancelled because SI AI service is disposed.');
    }
    cancellationToken.throwIfCancelled();

    final String authorizationHeader = '$_authorizationScheme $bearerToken';

    final http.Response response = await _client.post(
      Uri.parse(_endpoint),
      headers: <String, String>{
        'Content-Type': 'application/json',
        'Authorization': authorizationHeader,
      },
      body: jsonEncode(body),
    );

    if (_isDisposed) {
      throw OperationCancelledException('Operation cancelled because SI AI service is disposed.');
    }
    cancellationToken.throwIfCancelled();
    return response;
  }

  void dispose() {
    _isDisposed = true;
    if (_ownsClient) {
      _client.close();
    }
  }
}
