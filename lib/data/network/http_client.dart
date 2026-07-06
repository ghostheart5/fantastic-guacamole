// Dart SDK imports.
import 'dart:convert';

// Package imports.
import 'package:http/http.dart' as http;

class ApiClient {
  ApiClient({http.Client? client, Duration? timeout})
    : _client = client ?? http.Client(),
      _timeout = timeout ?? const Duration(seconds: 15);

  final http.Client _client;
  final Duration _timeout;

  Future<Map<String, dynamic>> getJson(
    Uri uri, {
    Map<String, String> headers = const <String, String>{},
  }) async {
    final http.Response response = await _client
        .get(uri, headers: headers)
        .timeout(_timeout);
    return _decodeJsonObject(response);
  }

  Future<Map<String, dynamic>> postJson(
    Uri uri, {
    required Map<String, dynamic> body,
    Map<String, String> headers = const <String, String>{},
  }) async {
    final Map<String, String> mergedHeaders = <String, String>{
      'content-type': 'application/json',
      ...headers,
    };
    final http.Response response = await _client
        .post(uri, headers: mergedHeaders, body: jsonEncode(body))
        .timeout(_timeout);
    return _decodeJsonObject(response);
  }

  Map<String, dynamic> _decodeJsonObject(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpClientException(
        'Request failed with status ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }

    final Object? decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const HttpClientException('Response JSON is not an object.');
    }
    return decoded;
  }
}

class HttpClientException implements Exception {
  const HttpClientException(this.message, {this.statusCode, this.body});

  final String message;
  final int? statusCode;
  final String? body;

  @override
  String toString() {
    return 'HttpClientException($message, statusCode: $statusCode)';
  }
}
