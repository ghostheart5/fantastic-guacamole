// Dart SDK imports.
import 'dart:async';
import 'dart:convert';

// Package imports.
import 'package:fantastic_guacamole/core/network/retry_executor.dart';
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
    final http.Response response = await runWithRetry<http.Response>(
      action: () async {
        final http.Response next = await _client
            .get(uri, headers: headers)
            .timeout(_timeout);
        if (_isTransient(next.statusCode)) {
          throw HttpClientException(
            'Transient GET failure',
            statusCode: next.statusCode,
          );
        }
        return next;
      },
      retryIf: (Object error) {
        return error is TimeoutException ||
            (error is HttpClientException &&
                _isTransient(error.statusCode ?? 0));
      },
    );
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
    final http.Response response = await runWithRetry<http.Response>(
      action: () async {
        final http.Response next = await _client
            .post(uri, headers: mergedHeaders, body: jsonEncode(body))
            .timeout(_timeout);
        if (_isTransient(next.statusCode)) {
          throw HttpClientException(
            'Transient POST failure',
            statusCode: next.statusCode,
          );
        }
        return next;
      },
      retryIf: (Object error) {
        return error is TimeoutException ||
            (error is HttpClientException &&
                _isTransient(error.statusCode ?? 0));
      },
    );
    return _decodeJsonObject(response);
  }

  bool _isTransient(int statusCode) {
    return statusCode == 408 || statusCode == 429 || statusCode >= 500;
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
