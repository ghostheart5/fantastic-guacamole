import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory temporaryDirectory;
  late String runnerPath;
  late String powerShellExecutable;

  setUpAll(() {
    temporaryDirectory = Directory.systemTemp.createTempSync(
      'chronospark-monkey-git-',
    );
    runnerPath = File('scripts/run_android_monkey_matrix.ps1').absolute.path;
    powerShellExecutable = Platform.isWindows ? 'powershell.exe' : 'pwsh';
  });

  tearDownAll(() {
    temporaryDirectory.deleteSync(recursive: true);
  });

  String psLiteral(String value) => "'${value.replaceAll("'", "''")}'";

  ProcessResult runFixture(String name, String body) {
    final File script = File('${temporaryDirectory.path}/$name.ps1');
    // Windows PowerShell 5.1 requires a BOM for UTF-8 fixture source.
    script.writeAsStringSync('''\ufeff
\$ErrorActionPreference = 'Stop'
\$originalLocation = (Get-Location).Path
. ${psLiteral(runnerPath)}
if ((Get-Location).Path -cne \$originalLocation) { throw 'Loading helpers changed the working directory.' }
$body
''');
    return Process.runSync(powerShellExecutable, <String>[
      '-NoProfile',
      '-NonInteractive',
      '-ExecutionPolicy',
      'Bypass',
      '-File',
      script.path,
    ]);
  }

  Map<String, dynamic> output(ProcessResult result) {
    expect(result.exitCode, 0, reason: result.stderr as String);
    return jsonDecode(result.stdout as String) as Map<String, dynamic>;
  }

  List<Map<String, dynamic>> probeSamples(Map<String, dynamic> receipt) =>
      (receipt['ProbeSamples'] as List<dynamic>).cast<Map<String, dynamic>>();

  Map<String, dynamic> probe(Map<String, dynamic> sample, String name) =>
      sample[name] as Map<String, dynamic>;

  test('records named and detached identity from a real Git repository', () {
    final Directory repository = Directory(
      '${temporaryDirectory.path}/source snapshot',
    )..createSync();
    final ProcessResult result = runFixture('source-identity', '''
\$fixtureRepository = ${psLiteral(repository.path)}
& git -C \$fixtureRepository init --quiet --initial-branch=fixture
if (\$LASTEXITCODE -ne 0) { throw 'Fixture init failed.' }
& git -C \$fixtureRepository -c user.name=ChronoSparkFixture -c user.email=fixture@example.invalid commit --quiet --allow-empty -m fixture
if (\$LASTEXITCODE -ne 0) { throw 'Fixture commit failed.' }
\$namedBranch = Get-GitEvidenceText -RepositoryRoot \$fixtureRepository -Arguments @('branch', '--show-current')
\$namedCommit = Get-GitEvidenceText -RepositoryRoot \$fixtureRepository -Arguments @('rev-parse', 'HEAD')
& git -C \$fixtureRepository checkout --quiet --detach
if (\$LASTEXITCODE -ne 0) { throw 'Fixture detach failed.' }
[ordered]@{
  namedBranch = \$namedBranch
  namedCommit = \$namedCommit
  detachedBranch = Get-GitEvidenceText -RepositoryRoot \$fixtureRepository -Arguments @('branch', '--show-current')
  detachedCommit = Get-GitEvidenceText -RepositoryRoot \$fixtureRepository -Arguments @('rev-parse', 'HEAD')
} | ConvertTo-Json -Compress
''');
    final Map<String, dynamic> receipt = output(result);
    expect(receipt['namedBranch'], 'fixture');
    expect(receipt['namedCommit'], matches(RegExp(r'^[a-f0-9]{40}$')));
    expect(receipt['detachedBranch'], '');
    expect(receipt['detachedCommit'], receipt['namedCommit']);
  });

  test('rejects a failed Git lookup instead of recording empty evidence', () {
    final Directory notRepository = Directory(
      '${temporaryDirectory.path}/not a repository',
    )..createSync();
    final ProcessResult result = runFixture('failed-identity', '''
\$rejected = \$false
try {
  Get-GitEvidenceText -RepositoryRoot ${psLiteral(notRepository.path)} -Arguments @('rev-parse', 'HEAD') | Out-Null
} catch {
  \$rejected = \$true
}
[ordered]@{ rejected = \$rejected } | ConvertTo-Json -Compress
''');
    expect(output(result)['rejected'], isTrue);
  });

  test('supports relative and absolute evidence roots without rebasing', () {
    final String repository = '${temporaryDirectory.path}/repository';
    final String externalEvidence = '${temporaryDirectory.path}/evidence root';
    final ProcessResult result = runFixture('artifact-roots', '''
[ordered]@{
  relative = Get-MonkeyRunRoot -RepositoryRoot ${psLiteral(repository)} -ArtifactsRoot 'artifacts/monkey' -RunId 'fixture-run'
  absolute = Get-MonkeyRunRoot -RepositoryRoot ${psLiteral(repository)} -ArtifactsRoot ${psLiteral(externalEvidence)} -RunId 'fixture-run'
} | ConvertTo-Json -Compress
''');
    final Map<String, dynamic> receipt = output(result);
    String normalize(String value) => value.replaceAll('\\', '/');
    expect(
      normalize(receipt['relative'] as String),
      normalize('$repository/artifacts/monkey/fixture-run'),
    );
    expect(
      normalize(receipt['absolute'] as String),
      normalize('$externalEvidence/fixture-run'),
    );
  });

  test('timed-out focus output cannot satisfy readiness', () {
    final ProcessResult result = runFixture('partial-timeout', r'''
function Invoke-Adb {
  param([string[]]$Arguments, [int]$TimeoutSeconds, [int]$TimeoutMilliseconds)
  if ($Arguments -contains 'pidof') {
    return [pscustomobject]@{ Output = @('100'); ExitCode = 0; TimedOut = $false }
  }
  return [pscustomobject]@{ Output = @('mCurrentFocus=Window{abc u0 com.ghostheart5.chronospark/.MainActivity}'); ExitCode = 0; TimedOut = $true }
}
Wait-ForPackageFocus -Serial 'fixture' -PackageName 'com.ghostheart5.chronospark' -TimeoutSeconds 1 -PollMilliseconds 100 | ConvertTo-Json -Compress -Depth 8
''');
    final Map<String, dynamic> receipt = output(result);
    expect(receipt['Ready'], isFalse);
    final List<Map<String, dynamic>> samples = probeSamples(receipt);
    expect(samples, isNotEmpty);
    expect(probe(samples.first, 'window')['timedOut'], isTrue);
    expect(probe(samples.first, 'window')['exitCode'], 0);
    expect(samples.first['validFocus'], isFalse);
    expect(
      samples.every(
        (Map<String, dynamic> sample) => sample['stableSamples'] == 0,
      ),
      isTrue,
    );
  });

  test('second stable sample arriving after the deadline cannot pass', () {
    final ProcessResult result = runFixture('late-stability', r'''
$script:windowCalls = 0
function Invoke-Adb {
  param([string[]]$Arguments, [int]$TimeoutSeconds, [int]$TimeoutMilliseconds)
  if ($Arguments -contains 'pidof') {
    return [pscustomobject]@{ Output = @('100'); ExitCode = 0; TimedOut = $false }
  }
  $script:windowCalls++
  if ($script:windowCalls -eq 2) { Start-Sleep -Milliseconds 1100 }
  return [pscustomobject]@{ Output = @('mCurrentFocus=Window{abc u0 com.ghostheart5.chronospark/.MainActivity}'); ExitCode = 0; TimedOut = $false }
}
Wait-ForPackageFocus -Serial 'fixture' -PackageName 'com.ghostheart5.chronospark' -TimeoutSeconds 1 -PollMilliseconds 100 | ConvertTo-Json -Compress -Depth 8
''');
    final Map<String, dynamic> receipt = output(result);
    expect(receipt['Ready'], isFalse);
    expect(receipt['ElapsedSeconds'], greaterThanOrEqualTo(1));
    final List<Map<String, dynamic>> samples = probeSamples(receipt);
    expect(samples.length, 2);
    expect(samples.last['deadlineExceeded'], isTrue);
    expect(samples.last['validFocus'], isFalse);
    expect(
      probe(samples.last, 'window')['timeoutMilliseconds'],
      lessThan(probe(samples.first, 'window')['timeoutMilliseconds'] as num),
    );
    expect(
      probe(samples.last, 'window')['durationMilliseconds'],
      greaterThanOrEqualTo(1000),
    );
  });

  test('hanging probe uses remaining budget and prevents another call', () {
    final ProcessResult result = runFixture('bounded-hang', r'''
$script:probeCalls = 0
function Invoke-Adb {
  param([string[]]$Arguments, [int]$TimeoutSeconds, [int]$TimeoutMilliseconds)
  $script:probeCalls++
  if ($TimeoutMilliseconds -le 0 -or $TimeoutMilliseconds -gt 1000) { throw 'Probe did not receive remaining budget.' }
  Start-Sleep -Milliseconds ($TimeoutMilliseconds + 30)
  return [pscustomobject]@{ Output = @('100'); ExitCode = -1; TimedOut = $true }
}
$readiness = Wait-ForPackageFocus -Serial 'fixture' -PackageName 'com.ghostheart5.chronospark' -TimeoutSeconds 1 -PollMilliseconds 100
if ($script:probeCalls -ne 1) { throw 'Another probe started after the deadline.' }
$readiness | ConvertTo-Json -Compress -Depth 8
''');
    final Map<String, dynamic> receipt = output(result);
    expect(receipt['Ready'], isFalse);
    final List<Map<String, dynamic>> samples = probeSamples(receipt);
    expect(samples.length, 1);
    expect(probe(samples.single, 'pid')['timedOut'], isTrue);
    expect(probe(samples.single, 'pid')['exitCode'], -1);
    expect(
      probe(samples.single, 'pid')['timeoutMilliseconds'],
      inInclusiveRange(1, 1000),
    );
    expect(samples.single['window'], isNull);
  });

  test(
    'transient timeout recovers only after two samples with the same PID',
    () {
      final ProcessResult result = runFixture('transient-recovery', r'''
$script:sample = 0
function Invoke-Adb {
  param([string[]]$Arguments, [int]$TimeoutSeconds, [int]$TimeoutMilliseconds)
  if ($TimeoutMilliseconds -le 0 -or $TimeoutMilliseconds -gt 5000) { throw 'Per-probe cap not respected.' }
  if ($Arguments -contains 'pidof') {
    $script:sample++
    $fixturePid = if ($script:sample -le 2) { '100' } else { '200' }
    return [pscustomobject]@{ Output = @($fixturePid); ExitCode = 0; TimedOut = $false }
  }
  return [pscustomobject]@{ Output = @('mCurrentFocus=Window{abc u0 com.ghostheart5.chronospark/.MainActivity}'); ExitCode = 0; TimedOut = ($script:sample -eq 1) }
}
Wait-ForPackageFocus -Serial 'fixture' -PackageName 'com.ghostheart5.chronospark' -TimeoutSeconds 30 -PollMilliseconds 100 | ConvertTo-Json -Compress -Depth 8
''');
      final Map<String, dynamic> receipt = output(result);
      expect(receipt['Ready'], isTrue);
      expect(receipt['LastPid'], '200');
      expect(receipt['ElapsedSeconds'], lessThan(30));
      final List<Map<String, dynamic>> samples = probeSamples(receipt);
      expect(
        samples
            .map((Map<String, dynamic> sample) => sample['stableSamples'])
            .toList(),
        <int>[0, 1, 1, 2],
      );
      expect(probe(samples.first, 'window')['timedOut'], isTrue);
      expect(samples.last['deadlineExceeded'], isFalse);
      expect(samples.last['observedPid'], '200');
      expect(samples[samples.length - 2]['observedPid'], '200');
      expect(samples.last['validFocus'], isTrue);
      expect(
        samples.last['observedFocus'],
        contains('com.ghostheart5.chronospark/.MainActivity'),
      );
    },
  );
}
