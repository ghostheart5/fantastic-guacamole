import 'dart:convert';
import 'dart:io';

import 'package:fantastic_guacamole/config/firebase_identity.dart';

enum ProductionTarget { all, android, ios }

const List<String> commonRequiredProductionVariables = <String>[
  'CHRONOSPARK_SUPABASE_URL',
  'CHRONOSPARK_SUPABASE_ANON_KEY',
  'CHRONOSPARK_RECEIPT_VERIFY_ENDPOINT',
  'CHRONOSPARK_AI_PROXY_ENDPOINT',
  'CHRONOSPARK_ACCOUNT_DELETE_ENDPOINT',
];

List<String> validateProductionConfiguration(
  Map<String, String> values, {
  String? googleServicesJson,
  ProductionTarget target = ProductionTarget.all,
}) {
  final List<String> failures = <String>[];
  final List<String> requiredVariables = <String>[
    ...commonRequiredProductionVariables,
    if (target != ProductionTarget.ios) 'CHRONOSPARK_ANDROID_SHA256_CERT',
    if (target != ProductionTarget.android) 'CHRONOSPARK_IOS_TEAM_ID',
  ];
  for (final String name in requiredVariables) {
    final String value = values[name]?.trim() ?? '';
    if (value.isEmpty) {
      failures.add('$name is required.');
    } else if (_looksLikePlaceholder(value)) {
      failures.add('$name contains a placeholder or local-only value.');
    }
  }

  final Map<String, Uri> urls = <String, Uri>{};
  for (final String name in <String>[
    'CHRONOSPARK_SUPABASE_URL',
    'CHRONOSPARK_RECEIPT_VERIFY_ENDPOINT',
    'CHRONOSPARK_AI_PROXY_ENDPOINT',
    'CHRONOSPARK_AI_REPORT_ENDPOINT',
    'CHRONOSPARK_ACCOUNT_DELETE_ENDPOINT',
  ]) {
    final String raw = values[name]?.trim() ?? '';
    if (raw.isEmpty) {
      continue;
    }
    final Uri? uri = Uri.tryParse(raw);
    if (uri == null ||
        !uri.isAbsolute ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        _isLocalOrPrivateHost(uri.host)) {
      failures.add('$name must be a public absolute HTTPS URL.');
      continue;
    }
    if (name == 'CHRONOSPARK_SUPABASE_URL' &&
        uri.path.isNotEmpty &&
        uri.path != '/') {
      failures.add('CHRONOSPARK_SUPABASE_URL must not include an API path.');
    }
    if (name != 'CHRONOSPARK_SUPABASE_URL' &&
        (uri.path.isEmpty || uri.path == '/')) {
      failures.add('$name must identify a non-root service endpoint.');
    }
    urls[name] = uri;
  }

  final Uri? supabaseUri = urls['CHRONOSPARK_SUPABASE_URL'];
  const Map<String, String> expectedFunctionPaths = <String, String>{
    'CHRONOSPARK_RECEIPT_VERIFY_ENDPOINT': '/functions/v1/verify-receipt',
    'CHRONOSPARK_AI_PROXY_ENDPOINT': '/functions/v1/ai-proxy',
    'CHRONOSPARK_AI_REPORT_ENDPOINT': '/functions/v1/ai-report',
    'CHRONOSPARK_ACCOUNT_DELETE_ENDPOINT': '/functions/v1/account-delete',
  };
  for (final MapEntry<String, String> expected
      in expectedFunctionPaths.entries) {
    final Uri? endpoint = urls[expected.key];
    if (supabaseUri == null || endpoint == null) continue;
    final bool sameOrigin =
        endpoint.scheme == supabaseUri.scheme &&
        endpoint.host == supabaseUri.host &&
        endpoint.port == supabaseUri.port;
    if (!sameOrigin ||
        endpoint.path != expected.value ||
        endpoint.hasQuery ||
        endpoint.hasFragment) {
      failures.add(
        '${expected.key} must be the exact ${expected.value.split('/').last} '
        'function on CHRONOSPARK_SUPABASE_URL.',
      );
    }
  }

  final Set<String> serviceEndpoints = <String>{};
  for (final String name in <String>[
    'CHRONOSPARK_RECEIPT_VERIFY_ENDPOINT',
    'CHRONOSPARK_AI_PROXY_ENDPOINT',
    'CHRONOSPARK_ACCOUNT_DELETE_ENDPOINT',
  ]) {
    final Uri? uri = urls[name];
    if (uri != null && !serviceEndpoints.add(uri.toString())) {
      failures.add('$name must not reuse another production service endpoint.');
    }
  }

  final String anonKey = values['CHRONOSPARK_SUPABASE_ANON_KEY']?.trim() ?? '';
  if (anonKey.isNotEmpty &&
      !_looksLikePlaceholder(anonKey) &&
      !_isSupabasePublishableKey(anonKey)) {
    failures.add(
      'CHRONOSPARK_SUPABASE_ANON_KEY must be a Supabase anon JWT or publishable key.',
    );
  }

  final String fingerprint =
      values['CHRONOSPARK_ANDROID_SHA256_CERT']?.trim() ?? '';
  if (target != ProductionTarget.ios &&
      fingerprint.isNotEmpty &&
      !_looksLikePlaceholder(fingerprint) &&
      !RegExp(
        r'^(?:[0-9A-Fa-f]{2}:){31}[0-9A-Fa-f]{2}$|^[0-9A-Fa-f]{64}$',
      ).hasMatch(fingerprint)) {
    failures.add(
      'CHRONOSPARK_ANDROID_SHA256_CERT must contain exactly 32 SHA-256 bytes.',
    );
  }

  final String teamId = values['CHRONOSPARK_IOS_TEAM_ID']?.trim() ?? '';
  if (target != ProductionTarget.android &&
      teamId.isNotEmpty &&
      !_looksLikePlaceholder(teamId) &&
      !RegExp(r'^[A-Z0-9]{10}$').hasMatch(teamId)) {
    failures.add(
      'CHRONOSPARK_IOS_TEAM_ID must be a 10-character Apple team identifier.',
    );
  }

  if (googleServicesJson != null) {
    _validateGoogleServices(googleServicesJson, failures);
  }
  return failures;
}

void main(List<String> arguments) {
  String? googleServicesJson;
  ProductionTarget target = ProductionTarget.all;
  for (final String argument in arguments) {
    if (argument.startsWith('--google-services=')) {
      final String path = argument.substring('--google-services='.length);
      final File file = File(path);
      if (!file.existsSync()) {
        stderr.writeln('Production configuration guard failed:');
        stderr.writeln(' - Android Firebase configuration file is missing.');
        exitCode = 1;
        return;
      }
      googleServicesJson = file.readAsStringSync();
    } else if (argument.startsWith('--platform=')) {
      final String value = argument.substring('--platform='.length);
      final ProductionTarget? parsedTarget = switch (value) {
        'all' => ProductionTarget.all,
        'android' => ProductionTarget.android,
        'ios' => ProductionTarget.ios,
        _ => null,
      };
      if (parsedTarget == null) {
        stderr.writeln('Unknown platform: $value');
        exitCode = 64;
        return;
      }
      target = parsedTarget;
    } else {
      stderr.writeln('Unknown argument: $argument');
      exitCode = 64;
      return;
    }
  }

  final List<String> failures = validateProductionConfiguration(
    Platform.environment,
    googleServicesJson: googleServicesJson,
    target: target,
  );
  if (failures.isNotEmpty) {
    stderr.writeln('Production configuration guard failed:');
    for (final String failure in failures.toSet().toList()..sort()) {
      stderr.writeln(' - $failure');
    }
    exitCode = 1;
    return;
  }
  stdout.writeln('Production configuration guard passed.');
}

bool _looksLikePlaceholder(String value) {
  final String normalized = value.toLowerCase();
  return normalized.contains('<') ||
      normalized.contains('>') ||
      normalized.contains('your-domain') ||
      normalized.contains('example.com') ||
      normalized.contains('localhost') ||
      normalized.contains('127.0.0.1') ||
      normalized.contains('0.0.0.0');
}

bool _isLocalOrPrivateHost(String host) {
  final String normalized = host.toLowerCase();
  if (normalized == 'localhost' || normalized.endsWith('.local')) {
    return true;
  }
  final List<String> parts = normalized.split('.');
  if (parts.length != 4 ||
      parts.any((String part) => int.tryParse(part) == null)) {
    return false;
  }
  final List<int> octets = parts.map(int.parse).toList();
  return octets[0] == 10 ||
      octets[0] == 127 ||
      (octets[0] == 169 && octets[1] == 254) ||
      (octets[0] == 172 && octets[1] >= 16 && octets[1] <= 31) ||
      (octets[0] == 192 && octets[1] == 168);
}

bool _isSupabasePublishableKey(String key) {
  if (RegExp(r'^sb_publishable_[A-Za-z0-9_-]{20,}$').hasMatch(key)) {
    return true;
  }
  final List<String> segments = key.split('.');
  if (segments.length != 3 ||
      segments.any(
        (String segment) => !RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(segment),
      )) {
    return false;
  }
  try {
    final String normalized = base64Url.normalize(segments[1]);
    final Object? payload = jsonDecode(
      utf8.decode(base64Url.decode(normalized)),
    );
    return payload is Map && payload['role'] == 'anon';
  } on FormatException {
    return false;
  }
}

void _validateGoogleServices(String source, List<String> failures) {
  Object? decoded;
  try {
    decoded = jsonDecode(source);
  } on FormatException {
    failures.add('Android Firebase configuration must be valid JSON.');
    return;
  }
  if (decoded is! Map<String, dynamic>) {
    failures.add('Android Firebase configuration must contain a JSON object.');
    return;
  }
  final Object? projectInfoValue = decoded['project_info'];
  final Map<Object?, Object?> projectInfo = projectInfoValue is Map
      ? projectInfoValue
      : const <Object?, Object?>{};
  final String projectId = projectInfo['project_id']?.toString().trim() ?? '';
  final String projectNumber =
      projectInfo['project_number']?.toString().trim() ?? '';
  if (projectId.isEmpty || !RegExp(r'^\d+$').hasMatch(projectNumber)) {
    failures.add(
      'Android Firebase configuration must identify a Firebase project.',
    );
  } else if (!FirebaseIdentity.matchesExpectedProjectId(projectId)) {
    failures.add(
      'Android Firebase configuration must use the expected ChronoSpark project.',
    );
  }

  final Object? clientsValue = decoded['client'];
  final Iterable<Map<Object?, Object?>> clients = clientsValue is List
      ? clientsValue.whereType<Map<Object?, Object?>>()
      : const <Map<Object?, Object?>>[];
  final bool hasChronoSparkClient = clients.any((Map<Object?, Object?> client) {
    final Object? clientInfoValue = client['client_info'];
    final Map<Object?, Object?> clientInfo = clientInfoValue is Map
        ? clientInfoValue
        : const <Object?, Object?>{};
    final Object? androidInfoValue = clientInfo['android_client_info'];
    final Map<Object?, Object?> androidInfo = androidInfoValue is Map
        ? androidInfoValue
        : const <Object?, Object?>{};
    final Object? apiKeysValue = client['api_key'];
    final Iterable<Map<Object?, Object?>> apiKeys = apiKeysValue is List
        ? apiKeysValue.whereType<Map<Object?, Object?>>()
        : const <Map<Object?, Object?>>[];
    return androidInfo['package_name'] == 'com.ghostheart5.chronospark' &&
        apiKeys.any(
          (Map<Object?, Object?> key) =>
              (key['current_key']?.toString().trim() ?? '').isNotEmpty,
        );
  });
  if (!hasChronoSparkClient) {
    failures.add(
      'Android Firebase configuration must include the ChronoSpark package and an API key.',
    );
  }
}
