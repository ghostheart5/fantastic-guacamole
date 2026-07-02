import 'dart:convert';
import 'dart:io';

abstract class NetworkClientContract {
  Future<Map<String, dynamic>> get(String path, {Map<String, String>? headers});
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    Map<String, String>? headers,
  });
}

class NetworkClient implements NetworkClientContract {
  NetworkClient({this.baseUrl = '', this.timeout = const Duration(seconds: 30)});

  final String baseUrl;
  final Duration timeout;

  @override
  Future<Map<String, dynamic>> get(String path, {Map<String, String>? headers}) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse('$baseUrl$path'))
        ..headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      headers?.forEach((k, v) => request.headers.set(k, v));
      final response = await request.close().timeout(timeout);
      final body = await response.transform(utf8.decoder).join();
      return _decodeMap(body);
    } finally {
      client.close();
    }
  }

  @override
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    Map<String, String>? headers,
  }) async {
    final client = HttpClient();
    try {
      final request = await client.postUrl(Uri.parse('$baseUrl$path'))
        ..headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      headers?.forEach((k, v) => request.headers.set(k, v));
      request.write(jsonEncode(body));
      final response = await request.close().timeout(timeout);
      final responseBody = await response.transform(utf8.decoder).join();
      return _decodeMap(responseBody);
    } finally {
      client.close();
    }
  }

  Map<String, dynamic> _decodeMap(String payload) {
    final Object? decoded = jsonDecode(payload);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return decoded.map((dynamic key, dynamic value) => MapEntry(key.toString(), value));
    }
    throw const FormatException('Expected JSON object response');
  }
}

class MockNetworkClient implements NetworkClientContract {
  const MockNetworkClient();

  @override
  Future<Map<String, dynamic>> get(String path, {Map<String, String>? headers}) async {
    return <String, dynamic>{
      'ok': true,
      'source': 'mock',
      'method': 'GET',
      'path': path,
      'headers': headers ?? const <String, String>{},
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'data': <String, dynamic>{'message': 'Mock response for $path'},
    };
  }

  @override
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    Map<String, String>? headers,
  }) async {
    return <String, dynamic>{
      'ok': true,
      'source': 'mock',
      'method': 'POST',
      'path': path,
      'headers': headers ?? const <String, String>{},
      'echo': body,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'data': <String, dynamic>{'message': 'Mock write accepted for $path'},
    };
  }
}
