import 'dart:convert';

import 'package:fantastic_guacamole/config/launch_containment.dart';

/// Public build intent does not grant approval or override source containment.
abstract final class PublicReleaseProfile {
  static const String define = 'CHRONOSPARK_PUBLIC_RELEASE';
  static const String compiledValue = String.fromEnvironment(
    define,
    defaultValue: 'false',
  );
  static const bool requested = compiledValue == 'true';

  static const Map<String, String> requiredFlags = <String, String>{
    define: 'true',
    'CHRONOSPARK_APP_FLAVOR': 'prod',
    'CHRONOSPARK_BACKEND_MODE': 'cloud',
    'CHRONOSPARK_ENFORCE_PROD_READINESS': 'true',
    'CHRONOSPARK_ENABLE_CLOUD_SYNC': 'true',
    'CHRONOSPARK_INTERNAL_BILLING_TEST': 'false',
    'CHRONOSPARK_PUBLIC_CREDIT_ADMISSION_QA': 'false',
    'CHRONOSPARK_INTERNAL_BILLING_ACCOUNT_DIGESTS': '',
    'CHRONOSPARK_VERBOSE_LOGS': 'false',
    'CHRONOSPARK_ENABLE_MOCK_LOGIN': 'false',
    'CHRONOSPARK_ENABLE_MOCK_MODE': 'false',
    'CHRONOSPARK_ENABLE_TESTER_FULL_ACCESS': 'false',
    'CHRONOSPARK_PAYWALL_DISABLED': 'false',
    'CHRONOSPARK_ENABLE_RUNTIME_FEATURE_FLAGS': 'false',
    'CHRONOSPARK_ENABLE_ANALYTICS': 'false',
    'CHRONOSPARK_ENABLE_CRASH_REPORTING': 'false',
  };

  static const Map<String, Object> assistantPolicy = <String, Object>{
    'assistant_release_stage': 'general',
    'assistant_release_canary_basis_points': 0,
    'assistant_shadow_evaluation_enabled': false,
    'assistant_release_internal_account_digests': '',
    'kill_assistant_smart_planner_v2': false,
    'kill_assistant_si_console_v2': false,
    'kill_assistant_governed_memory': false,
    'kill_assistant_safety_critic': false,
    // This separately contained experiment is outside the public profile.
    'kill_assistant_planner_explanation': true,
  };

  static List<String> sourceReadinessIssues() => <String>[
    if (!LaunchContainment.cloudSyncEnabled)
      'Public cloud sync is not approved in source.',
    if (!LaunchContainment.cloudRestoreEnabled)
      'Public cloud restore is not approved in source.',
    if (!LaunchContainment.subscriptionsEnabled)
      'Public billing is not approved in source.',
    if (!LaunchContainment.externalAiEnabled)
      'Public external AI is not approved in source.',
    if (!LaunchContainment.creditSpendingEnabled)
      'Public credit spending is not approved in source.',
    if (!LaunchContainment.externalAiProviderRetentionVerified)
      'Provider retention review is missing in source.',
    if (!LaunchContainment.externalAiPrivacyReviewApproved)
      'Independent privacy/legal review is missing in source.',
    if (!LaunchContainment.externalAiSafetyReviewApproved)
      'Independent mental-health safety review is missing in source.',
  ];

  static List<String> validate(Map<String, String> values) {
    final value = values[define] ?? 'false';
    if (value != 'true' && value != 'false') {
      return <String>['$define must be true or false.'];
    }
    if (value == 'false') return <String>[];
    final issues = sourceReadinessIssues();
    for (final flag in requiredFlags.entries) {
      if (values[flag.key] != flag.value) {
        issues.add('Public release requires ${flag.key}=${flag.value}.');
      }
    }
    try {
      final Object? policy = jsonDecode(
        values['CHRONOSPARK_REMOTE_CONFIG_JSON'] ?? '',
      );
      if (policy is! Map<String, dynamic> ||
          policy.length != assistantPolicy.length ||
          assistantPolicy.entries.any(
            (entry) => policy[entry.key] != entry.value,
          )) {
        issues.add(
          'Public assistant policy must match the reviewed general profile without a private cohort.',
        );
      }
    } on FormatException {
      issues.add('Public assistant policy must be valid JSON.');
    }
    for (final endpoint in <String, String>{
      'CHRONOSPARK_AI_REPORT_ENDPOINT': 'ai-report',
      'CHRONOSPARK_PLANNER_EXPLANATION_ENDPOINT': 'planner-explanation',
    }.entries) {
      final base = (values['CHRONOSPARK_SUPABASE_URL'] ?? '').replaceFirst(
        RegExp(r'/$'),
        '',
      );
      if (values[endpoint.key] != '$base/functions/v1/${endpoint.value}') {
        issues.add(
          'Public release requires the exact ${endpoint.value} endpoint on its configured project.',
        );
      }
    }
    return issues;
  }
}
