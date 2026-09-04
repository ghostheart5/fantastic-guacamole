import 'dart:io';

import '../../tool/validate_github_workflows.dart' as workflow_validator;
import 'package:flutter_test/flutter_test.dart';

const Map<String, String> _requiredGates = <String, String>{
  'architecture boundary': './check_architecture.ps1',
  'Maestro flow contract': 'dart run tool/validate_maestro_flows.dart',
  'golden comparison contract': './scripts/golden_assertion_guard.ps1',
  'dependency audit': './scripts/dependency_audit.ps1',
  'GitHub workflow lint': r'$ACTIONLINT -no-color',
  'PowerShell parse gate': './scripts/powershell_parse_gate.ps1',
  'full Flutter coverage test':
      'dart run tool/run_flutter_tests.dart --report artifacts/flutter-test-evidence/flutter-tests.jsonl --manifest artifacts/flutter-test-evidence/flutter-tests-manifest.json --timeout-seconds 3600 -- test --no-pub --coverage --concurrency=1',
  'QA compile-time configuration':
      'dart run tool/run_flutter_tests.dart --report artifacts/flutter-test-evidence/qa-config-tests.jsonl --manifest artifacts/flutter-test-evidence/qa-config-tests-manifest.json --timeout-seconds 600 -- test/config/env_mode_resolution_test.dart --no-pub --dart-define-from-file=tool/qa_defines.json',
  'Linux integration': 'bash ./scripts/run_linux_integration_tests.sh',
  'coverage guard contract': './scripts/coverage_guard_contract.ps1',
  'coverage enforcement': './scripts/coverage_guard.ps1 -Mode ratchet',
  'Windows golden comparison':
      'dart run tool/run_flutter_tests.dart --report artifacts/windows-golden-evidence/golden-tests.jsonl --manifest artifacts/windows-golden-evidence/golden-tests-manifest.json --timeout-seconds 1200 -- test/features/auth/login_screen_golden_test.dart test/features/home/first_use_context_offer_card_test.dart test/features/nexus/nexus_screen_golden_test.dart test/features/settings/settings_screen_test.dart --no-pub --concurrency=1',
};

const Map<String, String> _requiredGateJobs = <String, String>{
  'architecture boundary': 'static-policy',
  'Maestro flow contract': 'static-policy',
  'golden comparison contract': 'static-policy',
  'dependency audit': 'static-policy',
  'GitHub workflow lint': 'static-policy',
  'PowerShell parse gate': 'static-policy',
  'coverage guard contract': 'static-policy',
  'full Flutter coverage test': 'flutter-tests',
  'QA compile-time configuration': 'flutter-tests',
  'coverage enforcement': 'flutter-tests',
  'Linux integration': 'linux-integration',
  'Windows golden comparison': 'windows-goldens',
};

const Map<String, String> _requiredDatabaseGates = <String, String>{
  'Edge Function gate failure contract':
      './scripts/edge_function_gate_contract.ps1',
  'Edge Function contract': './scripts/edge_function_gate.ps1 -RunTests',
  'database evidence verification': './scripts/verify_database_evidence.ps1',
  'migration replay policy': './scripts/supabase_migration_policy_contract.ps1',
  'disposable backend startup': 'supabase start',
  'database contract test': 'supabase test db',
  'database schema lint':
      'supabase db lint --local --schema public --fail-on error',
  'disposable backend shutdown': 'supabase stop --no-backup',
};

void main() {
  late String canonicalCi;
  late String canonicalDatabase;

  setUpAll(() {
    canonicalCi = File('.github/workflows/ci.yml').readAsStringSync();
    canonicalDatabase = File(
      '.github/workflows/supabase-database.yml',
    ).readAsStringSync();
  });

  test('canonical primary CI retains every required fail-closed gate', () {
    expect(workflow_validator.validatePrimaryCiSource(canonicalCi), isEmpty);
  });

  for (final MapEntry<String, String> gate in _requiredGates.entries) {
    test('rejects deletion of the ${gate.key} gate', () {
      final String requiredLine = '        run: ${gate.value}';
      expect(canonicalCi, contains(requiredLine));
      final String fixture = canonicalCi.replaceFirst(
        requiredLine,
        '        run: echo removed-required-gate',
      );

      final List<String> failures = workflow_validator.validatePrimaryCiSource(
        fixture,
      );

      expect(
        failures,
        contains(
          'Primary CI must retain the ${gate.key} gate with exact command: ${gate.value}',
        ),
      );
    });

    test('rejects continue-on-error on the ${gate.key} gate', () {
      final String requiredLine = '        run: ${gate.value}';
      expect(canonicalCi, contains(requiredLine));
      final String fixture = canonicalCi.replaceFirst(
        requiredLine,
        '        continue-on-error: true\n$requiredLine',
      );

      final List<String> failures = workflow_validator.validatePrimaryCiSource(
        fixture,
      );

      expect(
        failures,
        contains('Primary CI ${gate.key} gate must not use continue-on-error.'),
      );
    });

    test('rejects a conditional ${gate.key} gate', () {
      final String requiredLine = '        run: ${gate.value}';
      final String fixture = canonicalCi.replaceFirst(
        requiredLine,
        '        if: false\n$requiredLine',
      );

      expect(
        workflow_validator.validatePrimaryCiSource(fixture),
        contains('Primary CI ${gate.key} gate must run unconditionally.'),
      );
    });

    test('rejects ${gate.key} moved outside its required job', () {
      final String requiredLine = '        run: ${gate.value}';
      final String orphanJob =
          '  orphan-${_requiredGateJobs[gate.key]}-${gate.key.hashCode.abs()}:\n'
          '    steps:\n'
          '      - run: ${gate.value}\n\n';
      final String fixture = canonicalCi
          .replaceFirst(requiredLine, '        run: echo removed-required-gate')
          .replaceFirst('  test:\n', '$orphanJob  test:\n');

      expect(
        workflow_validator.validatePrimaryCiSource(fixture),
        contains(
          'Primary CI must retain the ${gate.key} gate with exact command: ${gate.value}',
        ),
      );
    });
  }

  test('rejects continue-on-error on a required category job', () {
    final String fixture = canonicalCi.replaceFirst(
      '  flutter-tests:\n    name:',
      '  flutter-tests:\n    continue-on-error: true\n    name:',
    );

    expect(
      workflow_validator.validatePrimaryCiSource(fixture),
      contains(
        'Primary CI required job flutter-tests must not use continue-on-error.',
      ),
    );
  });

  test('rejects an aggregate that can skip dependency failures', () {
    final String fixture = canonicalCi.replaceFirst(
      '    if: always()\n    needs:',
      '    if: success()\n    needs:',
    );
    expect(fixture, isNot(canonicalCi));

    expect(
      workflow_validator.validatePrimaryCiSource(fixture),
      contains(
        'Primary CI aggregate must be named Analyze & Test and run with if: always().',
      ),
    );
  });

  test('rejects an aggregate missing a required category dependency', () {
    final String fixture = canonicalCi.replaceFirst(', windows-goldens]', ']');
    expect(fixture, isNot(canonicalCi));

    expect(
      workflow_validator.validatePrimaryCiSource(fixture),
      contains(
        'Primary CI Analyze & Test aggregate must depend on every required category job.',
      ),
    );
  });

  test('rejects an aggregate that does not inspect every job result', () {
    final String fixture = canonicalCi.replaceFirst(
      r'WINDOWS_GOLDEN_RESULT: ${{ needs.windows-goldens.result }}',
      'WINDOWS_GOLDEN_RESULT: success',
    );
    expect(fixture, isNot(canonicalCi));

    expect(
      workflow_validator.validatePrimaryCiSource(fixture),
      contains(
        'Primary CI Analyze & Test aggregate must fail closed on every dependency result.',
      ),
    );
  });

  test('rejects continue-on-error on the required aggregate', () {
    final String fixture = canonicalCi.replaceFirst(
      '  test:\n    name:',
      '  test:\n    continue-on-error: true\n    name:',
    );

    expect(
      workflow_validator.validatePrimaryCiSource(fixture),
      contains(
        'Primary CI Analyze & Test aggregate must not use continue-on-error.',
      ),
    );
  });

  test('canonical database workflow retains every fail-closed gate', () {
    expect(
      workflow_validator.validateSupabaseDatabaseSource(canonicalDatabase),
      isEmpty,
    );
  });

  for (final MapEntry<String, String> gate in _requiredDatabaseGates.entries) {
    test('rejects deletion of the database ${gate.key} gate', () {
      final String requiredLine = '        run: ${gate.value}';
      expect(canonicalDatabase, contains(requiredLine));
      final String fixture = canonicalDatabase.replaceFirst(
        requiredLine,
        '        run: echo removed-required-gate',
      );

      final List<String> failures = workflow_validator
          .validateSupabaseDatabaseSource(fixture);

      expect(
        failures,
        contains(
          'Supabase database workflow must retain the ${gate.key} gate with exact command: ${gate.value}',
        ),
      );
    });

    test('rejects continue-on-error on the database ${gate.key} gate', () {
      final String requiredLine = '        run: ${gate.value}';
      expect(canonicalDatabase, contains(requiredLine));
      final String fixture = canonicalDatabase.replaceFirst(
        requiredLine,
        '        continue-on-error: true\n$requiredLine',
      );

      final List<String> failures = workflow_validator
          .validateSupabaseDatabaseSource(fixture);

      expect(
        failures,
        contains(
          'Supabase database workflow ${gate.key} gate must not use continue-on-error.',
        ),
      );
    });

    if (gate.key != 'disposable backend shutdown') {
      test('rejects a conditional database ${gate.key} gate', () {
        final String requiredLine = '        run: ${gate.value}';
        final String fixture = canonicalDatabase.replaceFirst(
          requiredLine,
          '        if: false\n$requiredLine',
        );

        expect(
          workflow_validator.validateSupabaseDatabaseSource(fixture),
          contains(
            'Supabase database workflow ${gate.key} gate must run unconditionally.',
          ),
        );
      });
    }
  }

  test('rejects continue-on-error on the database job', () {
    final String fixture = canonicalDatabase.replaceFirst(
      '  database:\n    runs-on:',
      '  database:\n    continue-on-error: true\n    runs-on:',
    );

    expect(
      workflow_validator.validateSupabaseDatabaseSource(fixture),
      contains(
        'Supabase database workflow database job must not use continue-on-error.',
      ),
    );
  });

  test('rejects database shutdown that is not unconditional', () {
    final String fixture = canonicalDatabase.replaceFirst(
      '      - name: Stop disposable Supabase backend\n        if: always()',
      '      - name: Stop disposable Supabase backend\n        if: success()',
    );
    expect(fixture, isNot(canonicalDatabase));

    expect(
      workflow_validator.validateSupabaseDatabaseSource(fixture),
      contains(
        'Supabase database workflow shutdown gate must run with if: always().',
      ),
    );
  });

  test('rejects database evidence upload that is not unconditional', () {
    final String fixture = canonicalDatabase.replaceFirst(
      '      - name: Upload database and Edge evidence\n        if: always()',
      '      - name: Upload database and Edge evidence\n        if: success()',
    );

    expect(
      workflow_validator.validateSupabaseDatabaseSource(fixture),
      contains(
        'Supabase database workflow must always upload exact-source and Edge JUnit evidence.',
      ),
    );
  });

  test('rejects a database workflow push outside main', () {
    final String fixture = canonicalDatabase.replaceFirst(
      '    branches: ["main"]',
      '    branches: ["main", "feature"]',
    );
    expect(fixture, isNot(canonicalDatabase));

    expect(
      workflow_validator.validateSupabaseDatabaseSource(fixture),
      contains(
        'Supabase database workflow push trigger must target only main.',
      ),
    );
  });

  test('rejects a database workflow pull request outside main', () {
    final int pullRequestIndex = canonicalDatabase.indexOf('  pull_request:');
    expect(pullRequestIndex, greaterThanOrEqualTo(0));
    final String fixture = canonicalDatabase.replaceFirst(
      '    branches: ["main"]',
      '    branches: ["feature"]',
      pullRequestIndex,
    );

    expect(
      workflow_validator.validateSupabaseDatabaseSource(fixture),
      contains(
        'Supabase database workflow pull request trigger must target only main.',
      ),
    );
  });

  test('rejects deletion of the reusable workflow trigger', () {
    final String fixture = canonicalDatabase.replaceFirst(
      '  workflow_call:\n',
      '',
    );
    expect(fixture, isNot(canonicalDatabase));

    expect(
      workflow_validator.validateSupabaseDatabaseSource(fixture),
      contains(
        'Supabase database workflow must retain the workflow_call trigger.',
      ),
    );
  });
}
