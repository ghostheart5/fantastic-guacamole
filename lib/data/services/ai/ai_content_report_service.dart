import 'dart:convert';

import 'package:fantastic_guacamole/config/env.dart';
import 'package:fantastic_guacamole/data/network/secure_endpoint.dart';
import 'package:http/http.dart' as http;

enum AiContentReportReason { unsafe, inaccurate, privacy, other }

extension AiContentReportReasonCode on AiContentReportReason {
  String get code => switch (this) {
    AiContentReportReason.unsafe => 'unsafe_or_harmful',
    AiContentReportReason.inaccurate => 'misleading_or_inaccurate',
    AiContentReportReason.privacy => 'privacy_concern',
    AiContentReportReason.other => 'other',
  };
}

/// Submits a user-selected AI response for safety review.
///
/// The response text is sent only after the user explicitly chooses a report
/// reason. It is bounded before transport and never includes credentials,
/// prompts, history, or local diagnostics.
class AiContentReportService {
  AiContentReportService({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  Future<void> submit({
    required String responseText,
    required AiContentReportReason reason,
  }) async {
    final Uri? endpoint = parseSecureHttpsEndpoint(Env.aiReportEndpoint);
    if (endpoint == null) {
      throw const AiContentReportException(
        'AI reporting is not available in this build.',
      );
    }
    final String? accessToken = currentSupabaseAccessToken();
    if (accessToken == null) {
      throw const AiContentReportException(
        'Sign in is required to report an AI response.',
      );
    }

    final String content = responseText.trim();
    if (content.isEmpty) {
      throw const AiContentReportException('The selected response is empty.');
    }
    final String boundedContent = content.length <= 4000
        ? content
        : content.substring(0, 4000);

    final http.Response response = await _client
        .post(
          endpoint,
          headers: <String, String>{
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(<String, String>{
            'reason': reason.code,
            'content': boundedContent,
          }),
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const AiContentReportException(
        'The report could not be submitted. Please try again.',
      );
    }
  }
}

class AiContentReportException implements Exception {
  const AiContentReportException(this.message);

  final String message;

  @override
  String toString() => message;
}
