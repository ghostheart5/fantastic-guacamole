import 'dart:convert';
import 'dart:math';

import 'package:fantastic_guacamole/domain/entities/planner_explanation_contract.dart';
import 'package:http/http.dart' as http;

final class PlannerExplanationServiceException implements Exception {
  const PlannerExplanationServiceException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'PlannerExplanationServiceException($code, $message)';
}

final class DisabledPlannerExplanationPort implements PlannerExplanationPort {
  const DisabledPlannerExplanationPort();

  @override
  Future<PlannerExplanationQuote> quote(PlannerExplanationPacket packet) {
    throw const PlannerExplanationServiceException(
      'external_ai_disabled',
      'Optional external AI explanation is disabled.',
    );
  }

  @override
  Future<PlannerExplanationResult> execute({
    required PlannerExplanationPacket packet,
    required PlannerExplanationQuote quote,
  }) {
    throw const PlannerExplanationServiceException(
      'external_ai_disabled',
      'Optional external AI explanation is disabled.',
    );
  }
}

final class HttpPlannerExplanationService implements PlannerExplanationPort {
  HttpPlannerExplanationService({
    required this.endpoint,
    required this.apiKey,
    required this.accessToken,
    required this._client,
    String Function()? requestIdFactory,
    this.timeout = const Duration(seconds: 18),
  }) : _requestIdFactory = requestIdFactory ?? _newRequestId {
    if (endpoint.scheme != 'https' ||
        endpoint.host.isEmpty ||
        endpoint.path != '/functions/v1/planner-explanation' ||
        apiKey.trim().isEmpty) {
      throw const PlannerExplanationServiceException(
        'invalid_endpoint_configuration',
        'Planner explanation requires its first-party HTTPS endpoint.',
      );
    }
  }

  final Uri endpoint;
  final String apiKey;
  final Future<String?> Function() accessToken;
  final Duration timeout;
  final http.Client _client;
  final String Function() _requestIdFactory;

  @override
  Future<PlannerExplanationQuote> quote(PlannerExplanationPacket packet) async {
    packet.validateForExternalProcessing();
    final String requestId = _requestIdFactory();
    final Map<String, Object?> json = await _post(<String, Object?>{
      'schemaVersion': plannerExplanationSchemaVersion,
      'operation': 'quote',
      'surface': plannerExplanationSurface,
      'requestId': requestId,
      ...packet.toRequestJson(),
    });
    final PlannerExplanationQuote quote = PlannerExplanationQuote.fromJson(
      json,
    );
    if (quote.requestId != requestId) {
      throw const PlannerExplanationServiceException(
        'quote_request_mismatch',
        'The quote did not belong to this explanation request.',
      );
    }
    return quote;
  }

  @override
  Future<PlannerExplanationResult> execute({
    required PlannerExplanationPacket packet,
    required PlannerExplanationQuote quote,
  }) async {
    packet.validateForExternalProcessing();
    if (quote.expiresAt.isBefore(DateTime.now().toUtc())) {
      throw const PlannerExplanationServiceException(
        'quote_expired',
        'The credit quote expired before confirmation.',
      );
    }
    final Map<String, Object?> json = await _post(<String, Object?>{
      'schemaVersion': plannerExplanationSchemaVersion,
      'operation': 'execute',
      'surface': plannerExplanationSurface,
      'requestId': quote.requestId,
      ...packet.toRequestJson(),
      'quoteId': quote.quoteId,
      'expectedCredits': quote.expectedCredits,
      'disclosureVersion': quote.disclosureVersion,
      'consentAccepted': true,
    });
    final PlannerExplanationResult result = PlannerExplanationResult.fromJson(
      json,
    );
    if (result.requestId != quote.requestId ||
        result.expectedCredits != quote.expectedCredits) {
      throw const PlannerExplanationServiceException(
        'result_quote_mismatch',
        'The explanation result did not match the confirmed credit quote.',
      );
    }
    result.validateAgainst(packet);
    return result;
  }

  Future<Map<String, Object?>> _post(Map<String, Object?> body) async {
    final String? token = (await accessToken())?.trim();
    if (token == null || token.isEmpty) {
      throw const PlannerExplanationServiceException(
        'authentication_required',
        'Sign in again before requesting an external explanation.',
      );
    }
    final http.Response response;
    try {
      response = await _client
          .post(
            endpoint,
            headers: <String, String>{
              'Authorization': 'Bearer $token',
              'apikey': apiKey,
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(timeout);
    } on Object {
      throw const PlannerExplanationServiceException(
        'request_failed',
        'The external explanation request did not complete. No plan was changed.',
      );
    }
    final Map<String, Object?> json = _decodeObject(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final Object? rawCode = json['error'];
      final String code = rawCode is String && rawCode.trim().isNotEmpty
          ? rawCode.trim()
          : 'request_rejected';
      throw PlannerExplanationServiceException(
        code,
        'The external explanation was not generated. No plan was changed.',
      );
    }
    return json;
  }

  static Map<String, Object?> _decodeObject(String body) {
    try {
      final Object? decoded = jsonDecode(body);
      if (decoded is! Map) {
        throw const FormatException('not an object');
      }
      return decoded.map<String, Object?>(
        (Object? key, Object? value) => MapEntry(key.toString(), value),
      );
    } on FormatException {
      throw const PlannerExplanationServiceException(
        'invalid_response_json',
        'The explanation service returned an invalid response.',
      );
    }
  }

  static String _newRequestId() {
    final Random random = Random.secure();
    final String entropy = base64Url
        .encode(List<int>.generate(18, (_) => random.nextInt(256)))
        .replaceAll('=', '');
    return 'planner-explanation-${DateTime.now().toUtc().microsecondsSinceEpoch}-$entropy';
  }
}
