import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

const Set<String> _criticalLints = <String>{
  'avoid_void_async',
  'deprecated_member_use_from_same_package',
  'discarded_futures',
  'only_throw_errors',
  'unawaited_futures',
};

const Set<String> _cannotIgnoreDiagnostics = <String>{
  ..._criticalLints,
  'dead_code',
  'invalid_use_of_protected_member',
  'invalid_use_of_visible_for_testing_member',
  'unused_import',
  'unused_local_variable',
};

void main() {
  test(
    'static analysis policy is strict, supported, and cannot be bypassed',
    () {
      final File policyFile = File('analysis_options.yaml');
      expect(policyFile.existsSync(), isTrue);

      final String source = policyFile.readAsStringSync();
      final Object? parsed = loadYaml(source);
      expect(parsed, isA<YamlMap>());
      final YamlMap policy = parsed! as YamlMap;

      expect(policy['include'], 'package:flutter_lints/flutter.yaml');
      expect(policy.containsKey('avoid_importing_flutter'), isFalse);

      final YamlMap analyzer = policy['analyzer'] as YamlMap;
      final Set<String> excluded = (analyzer['exclude'] as YamlList)
          .map((Object? value) => value.toString())
          .toSet();
      expect(
        excluded,
        <String>{'build/**'},
        reason: 'Source roots must not be silently excluded from analysis.',
      );

      final Set<String> cannotIgnore = (analyzer['cannot-ignore'] as YamlList)
          .map((Object? value) => value.toString())
          .toSet();
      expect(cannotIgnore, containsAll(_cannotIgnoreDiagnostics));

      final YamlMap errors = analyzer['errors'] as YamlMap;
      expect(
        errors.values,
        everyElement('error'),
        reason: 'Explicit diagnostics must not be downgraded or ignored.',
      );
      for (final String diagnostic in _cannotIgnoreDiagnostics) {
        expect(
          errors[diagnostic],
          'error',
          reason: '$diagnostic must fail every analyzer invocation.',
        );
      }

      final YamlMap language = analyzer['language'] as YamlMap;
      expect(language['strict-casts'], isTrue);
      expect(language['strict-inference'], isTrue);
      expect(language['strict-raw-types'], isTrue);

      final YamlMap linter = policy['linter'] as YamlMap;
      final YamlMap rules = linter['rules'] as YamlMap;
      for (final String lint in _criticalLints) {
        expect(rules[lint], isTrue, reason: '$lint must remain enabled.');
      }
      expect(
        rules.values.where((Object? value) => value == false),
        isEmpty,
        reason: 'Disabled rules silently weaken the inherited lint policy.',
      );
    },
  );

  test('local static gates cover every maintained Dart source root', () {
    const String formatCommand =
        'dart format --output=none --set-exit-if-changed '
        'lib test integration_test tool scripts';

    final String strictGate = File(
      'scripts/strict_gate.ps1',
    ).readAsStringSync();
    expect(strictGate, contains(formatCommand));
    expect(strictGate, contains('flutter analyze --fatal-infos'));

    final String orchestrator = File('run-all-tests.ps1').readAsStringSync();
    expect(
      orchestrator,
      contains(
        "Invoke-Stage '2. Format verification' \$dart "
        "@('format','--output=none','--set-exit-if-changed','lib','test',"
        "'integration_test','tool','scripts') \$projectRoot",
      ),
    );
    expect(orchestrator, contains("@('analyze','--fatal-infos')"));

    final String assistantVerifier = File(
      'tool/verify_assistant_rebuild.ps1',
    ).readAsStringSync();
    expect(assistantVerifier, contains('flutter analyze --fatal-infos'));
    expect(assistantVerifier, isNot(contains('--no-fatal-infos')));
  });

  test('Edge Function gate bounds stages and requires JUnit test evidence', () {
    final String gate = File(
      'scripts/edge_function_gate.ps1',
    ).readAsStringSync();
    final int formatIndex = gate.indexOf("-Name 'Deno format check'");
    final int lintIndex = gate.indexOf("-Name 'Deno lint'");
    final int checkIndex = gate.indexOf(
      '-Name "Deno type check for \$entrypoint"',
    );
    final int testIndex = gate.indexOf("-Name 'Deno test'");

    expect(formatIndex, greaterThanOrEqualTo(0));
    expect(lintIndex, greaterThan(formatIndex));
    expect(checkIndex, greaterThan(lintIndex));
    expect(testIndex, greaterThan(checkIndex));
    expect(gate, contains(r'$process.WaitForExit($TimeoutSeconds * 1000)'));
    expect(gate, contains(r'timed out after $TimeoutSeconds seconds.'));
    expect(gate, contains("'--fail-fast=1'"));
    expect(gate, contains(r'"--junit-path=$resolvedTestReportPath"'));
    expect(gate, contains(r'[xml]$report = Get-Content'));
    expect(
      gate,
      contains('Deno test completed without the required JUnit report:'),
    );
    expect(gate, contains('Deno test JUnit report is incomplete or invalid:'));
    expect(
      gate,
      contains("throw 'Deno test JUnit report contains no test cases.'"),
    );
    expect(
      gate,
      contains("throw 'Deno test JUnit report contains no completed tests.'"),
    );
    expect(
      gate,
      contains('Deno test JUnit report records \$(\$failures.Count) failures'),
    );
    expect(gate, contains('Deno test completion evidence:'));
    expect(
      gate,
      contains(
        "throw 'No Supabase Edge Function TypeScript files were found.'",
      ),
    );
    expect(
      gate,
      contains("throw 'No Supabase Edge Function index.ts files were found.'"),
    );
    expect(
      gate,
      contains(
        "throw 'RunTests was requested, but no Supabase Edge Function tests were found.'",
      ),
    );
  });
}
