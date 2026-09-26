import 'dart:convert';
import 'dart:io';

import 'package:fantastic_guacamole/config/public_release_profile.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../scripts/validate_production_config.dart';

void main() {
  Map<String, String> publicValues() => <String, String>{
    ...PublicReleaseProfile.requiredFlags,
    'CHRONOSPARK_REMOTE_CONFIG_JSON': jsonEncode(
      PublicReleaseProfile.assistantPolicy,
    ),
    'CHRONOSPARK_SUPABASE_URL': 'https://project-ref.supabase.co',
    'CHRONOSPARK_AI_REPORT_ENDPOINT':
        'https://project-ref.supabase.co/functions/v1/ai-report',
    'CHRONOSPARK_PLANNER_EXPLANATION_ENDPOINT':
        'https://project-ref.supabase.co/functions/v1/planner-explanation',
  };

  test(
    'private default remains separate and public intent cannot approve source',
    () {
      expect(PublicReleaseProfile.requested, isFalse);
      expect(PublicReleaseProfile.validate(<String, String>{}), isEmpty);
      final issues = PublicReleaseProfile.validate(publicValues());
      expect(
        issues,
        contains(
          'Privacy and data-disclosure validation is missing in source.',
        ),
      );
      expect(issues, contains('AI safety validation is missing in source.'));
      expect(issues, contains('Public cloud sync is not approved in source.'));
    },
  );

  test('public config guard rejects every internal bypass and wrong flag', () {
    for (final flag in PublicReleaseProfile.requiredFlags.entries) {
      final values = publicValues();
      values[flag.key] = flag.value == 'true' ? 'false' : 'true';
      if (flag.key == PublicReleaseProfile.define) continue;
      expect(
        PublicReleaseProfile.validate(values),
        contains('Public release requires ${flag.key}=${flag.value}.'),
        reason: flag.key,
      );
    }
    expect(
      PublicReleaseProfile.validate(<String, String>{
        PublicReleaseProfile.define: 'yes',
      }),
      isNotEmpty,
    );
  });

  test('general policy and exact reporting endpoints are mandatory', () {
    for (final policy in <Object>[
      <String, Object>{
        ...PublicReleaseProfile.assistantPolicy,
        'assistant_release_stage': 'internal',
      },
      <String, Object>{
        ...PublicReleaseProfile.assistantPolicy,
        'assistant_release_internal_account_digests': 'a' * 64,
      },
      <String, Object>{
        ...PublicReleaseProfile.assistantPolicy,
        'kill_assistant_planner_explanation': false,
      },
      <String, Object>{...PublicReleaseProfile.assistantPolicy, 'extra': true},
    ]) {
      final issues = PublicReleaseProfile.validate(<String, String>{
        ...publicValues(),
        'CHRONOSPARK_REMOTE_CONFIG_JSON': jsonEncode(policy),
      });
      expect(
        issues.any((issue) => issue.startsWith('Public assistant policy')),
        isTrue,
      );
    }
    expect(
      PublicReleaseProfile.validate(<String, String>{
        ...publicValues(),
        'CHRONOSPARK_AI_REPORT_ENDPOINT':
            'https://another-project.supabase.co/functions/v1/ai-report',
      }),
      contains(
        'Public release requires the exact ai-report endpoint on its configured project.',
      ),
    );
  });

  test(
    'production entry point enforces public approvals and Android scope',
    () {
      final issues = validateProductionConfiguration(
        publicValues(),
        target: ProductionTarget.ios,
      );
      expect(
        issues,
        contains('The public release profile supports Android only.'),
      );
      expect(issues, contains('AI safety validation is missing in source.'));
    },
  );

  test('committed public policy matches the validator contract', () {
    expect(
      jsonDecode(File('tool/public_assistant_release.json').readAsStringSync()),
      PublicReleaseProfile.assistantPolicy,
    );
  });
}
