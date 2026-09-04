import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'architecture checker scans the current repository and passes',
    () async {
      final ProcessResult result = await _runArchitectureChecker();
      final String output = _combinedOutput(result);

      expect(
        result.exitCode,
        0,
        reason:
            'The current repository must satisfy the complete architecture '
            'gate, including composite repository ownership.\n$output',
      );
      expect(output, contains('ARCHITECTURE CHECK PASSED'));
      expect(
        RegExp(r'Scanned [1-9]\d* Dart files\.').hasMatch(output),
        isTrue,
        reason:
            'A passing architecture check must prove it scanned a non-empty '
            'Dart source tree.\n$output',
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'architecture checker rejects every forbidden dependency class',
    () async {
      const List<_ForbiddenDependencyFixture>
      fixtures = <_ForbiddenDependencyFixture>[
        _ForbiddenDependencyFixture(
          relativePath: 'lib/data/services/fixture_service.dart',
          importUri:
              'package:fantastic_guacamole/state/services/forbidden.dart',
          clause: 'show',
          expectedMessage: 'data/services must stay infra-only',
        ),
        _ForbiddenDependencyFixture(
          relativePath: 'lib/state/services/fixture_service.dart',
          importUri: 'package:fantastic_guacamole/system/forbidden.dart',
          clause: 'hide',
          expectedMessage:
              'state/services must not depend on system/features/engine',
        ),
        _ForbiddenDependencyFixture(
          relativePath: 'lib/system/fixture_system.dart',
          importUri: 'package:fantastic_guacamole/engine/si/forbidden.dart',
          clause: 'show',
          expectedMessage: 'system/* must stay platform/plugin-oriented',
        ),
        _ForbiddenDependencyFixture(
          relativePath: 'lib/engine/planning/fixture_engine.dart',
          importUri: 'package:fantastic_guacamole/data/forbidden.dart',
          clause: 'hide',
          expectedMessage:
              'engine/planning must not depend on app/data/state/system',
        ),
        _ForbiddenDependencyFixture(
          relativePath: 'lib/features/auth/screens/fixture_screen.dart',
          importUri:
              'package:fantastic_guacamole/data/repositories/forbidden.dart',
          clause: 'show',
          expectedMessage:
              'feature presentation must depend on state/domain/ui/features only',
        ),
        _ForbiddenDependencyFixture(
          relativePath: 'lib/features/auth/screens/fixture_screen.dart',
          importUri: 'package:shared_preferences/shared_preferences.dart',
          clause: 'hide',
          expectedMessage:
              'feature presentation must not import shared_preferences directly',
        ),
        _ForbiddenDependencyFixture(
          relativePath: 'lib/data/di/fixture_registry.dart',
          importUri: 'package:flutter_riverpod/flutter_riverpod.dart',
          clause: 'show',
          expectedMessage:
              'data/* must not import Riverpod; provider composition belongs under state/providers',
        ),
      ];

      for (final _ForbiddenDependencyFixture fixture in fixtures) {
        final Directory fixtureRoot = await _createFixture(fixture);
        try {
          final ProcessResult result = await _runArchitectureChecker(
            root: fixtureRoot.path,
          );
          final String output = _combinedOutput(result);

          expect(
            result.exitCode,
            isNot(0),
            reason:
                '${fixture.relativePath} must make the architecture gate fail.\n'
                '$output',
          );
          expect(
            output,
            contains(
              '\n - ${fixture.relativePath}:1 -> ${fixture.expectedMessage} '
              '(import: ${_reportedImportPath(fixture.importUri)})',
            ),
            reason:
                'The gate must report the intended dependency rule using a '
                'project-relative path, even when the import has a multiline '
                '${fixture.clause} clause.\n$output',
          );
          expect(output, contains('Scanned 1 Dart files.'));
        } finally {
          await fixtureRoot.delete(recursive: true);
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'architecture checker rejects provider declarations under data',
    () async {
      const String relativePath =
          'lib/data/di/fixture_repository_providers.dart';
      final Directory fixtureRoot = await _createSourceFixture(
        relativePath,
        <String>[
          'final misplacedRepositoryProvider =',
          '    Provider<Object>((ref) => Object());',
          '',
        ].join('\n'),
      );

      try {
        final ProcessResult result = await _runArchitectureChecker(
          root: fixtureRoot.path,
        );
        final String output = _combinedOutput(result);

        expect(
          result.exitCode,
          isNot(0),
          reason:
              'A provider declaration under lib/data must make the '
              'architecture gate fail.\n$output',
        );
        expect(
          output,
          contains(
            '\n - $relativePath:1 -> data/* must not declare providers; '
            'provider composition belongs under state/providers '
            '(provider: misplacedRepositoryProvider, factory: Provider)',
          ),
          reason:
              'The data-layer provider declaration must be reported by name '
              'and normalized project-relative path.\n$output',
        );
        expect(output, contains('Scanned 1 Dart files.'));
      } finally {
        await fixtureRoot.delete(recursive: true);
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

Future<ProcessResult> _runArchitectureChecker({String? root}) {
  final String powerShell = Platform.isWindows ? 'powershell' : 'pwsh';
  final List<String> arguments = <String>[
    '-NoProfile',
    if (Platform.isWindows) ...<String>['-ExecutionPolicy', 'Bypass'],
    '-File',
    'check_architecture.ps1',
    if (root != null) ...<String>['-Root', root],
  ];

  return Process.run(
    powerShell,
    arguments,
    workingDirectory: Directory.current.path,
  );
}

Future<Directory> _createFixture(_ForbiddenDependencyFixture fixture) async {
  return _createSourceFixture(fixture.relativePath, _fixtureSource(fixture));
}

Future<Directory> _createSourceFixture(
  String relativePath,
  String source,
) async {
  final Directory root = await Directory.systemTemp.createTemp(
    'chronospark_architecture_gate_',
  );
  final List<String> requiredDirectories = <String>[
    'lib/domain/entities',
    'lib/domain/interfaces',
    'lib/domain/usecases',
    'lib/engine/si',
    'lib/features',
  ];

  for (final String relativePath in requiredDirectories) {
    await Directory(
      _fixturePath(root.path, relativePath),
    ).create(recursive: true);
  }

  final File sourceFile = File(_fixturePath(root.path, relativePath));
  await sourceFile.parent.create(recursive: true);
  await sourceFile.writeAsString(source);
  return root;
}

String _fixtureSource(_ForbiddenDependencyFixture fixture) {
  final String importKeyword = <String>['im', 'port'].join();
  return <String>[
    "$importKeyword '${fixture.importUri}'",
    '    ${fixture.clause}',
    '        ForbiddenSymbol;',
    '',
    'class FixtureType {}',
    '',
  ].join('\n');
}

String _fixturePath(String root, String relativePath) {
  return <String>[
    root,
    ...relativePath.split('/'),
  ].join(Platform.pathSeparator);
}

String _combinedOutput(ProcessResult result) {
  return 'stdout:\n${result.stdout}\nstderr:\n${result.stderr}';
}

String _reportedImportPath(String uri) {
  const String prefix = 'package:fantastic_guacamole/';
  return uri.startsWith(prefix) ? uri.substring(prefix.length) : uri;
}

class _ForbiddenDependencyFixture {
  const _ForbiddenDependencyFixture({
    required this.relativePath,
    required this.importUri,
    required this.clause,
    required this.expectedMessage,
  });

  final String relativePath;
  final String importUri;
  final String clause;
  final String expectedMessage;
}
