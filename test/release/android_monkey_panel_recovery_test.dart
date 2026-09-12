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
. ${psLiteral(runnerPath)} -RepositoryRoot ${psLiteral(temporaryDirectory.path)}
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

  final scenarios = <String, Map<String, Object>>{
    'closes only the notification shade': {
      'focus': 'mCurrentFocus=Window{6d8f6c u0 NotificationShade}',
      'passed': true,
      'collapsed': true,
      'calls': 2,
    },
    'leaves app focus unchanged': {
      'focus':
          'mCurrentFocus=Window{abc u0 com.ghostheart5.chronospark/.MainActivity}',
      'passed': true,
      'collapsed': false,
      'calls': 1,
    },
    'does not dismiss an app ANR dialog': {
      'focus':
          'mCurrentFocus=Window{abc u0 Application Not Responding: com.ghostheart5.chronospark}',
      'passed': true,
      'collapsed': false,
      'calls': 1,
    },
    'fails a window read error': {
      'focus': '',
      'windowExit': 1,
      'passed': false,
      'collapsed': false,
      'calls': 1,
    },
    'fails a window read timeout': {
      'focus': '',
      'windowTimeout': true,
      'passed': false,
      'collapsed': false,
      'calls': 1,
    },
    'fails a rejected collapse': {
      'focus': 'mCurrentFocus=Window{6d8f6c u0 NotificationShade}',
      'collapseExit': 1,
      'passed': false,
      'collapsed': false,
      'calls': 2,
    },
    'fails a timed out collapse': {
      'focus': 'mCurrentFocus=Window{6d8f6c u0 NotificationShade}',
      'collapseTimeout': true,
      'passed': false,
      'collapsed': false,
      'calls': 2,
    },
    'rejects a phone before ADB': {
      'serial': '192.168.1.174:37567',
      'focus': '',
      'rejected': true,
      'calls': 0,
    },
  };
  for (final entry in scenarios.entries) {
    test(entry.key, () {
      final scenario = entry.value;
      final result = runFixture(
        'panel-case',
        r'''
$script:scenario = __SCENARIO__ | ConvertFrom-Json
$script:calls = 0
function Invoke-Adb {
    param([string[]]$Arguments)
    $script:calls++
    $command = $Arguments -join ' '
    if ($command -match 'dumpsys window displays') {
        return [pscustomobject]@{Output=@($script:scenario.focus);ExitCode=[int]$script:scenario.windowExit;TimedOut=[bool]$script:scenario.windowTimeout}
    }
    if ($command -match 'cmd statusbar collapse') {
        return [pscustomobject]@{Output=@();ExitCode=[int]$script:scenario.collapseExit;TimedOut=[bool]$script:scenario.collapseTimeout}
    }
    throw "Unexpected command: $command"
}
$serial = if ($script:scenario.serial) { $script:scenario.serial } else { 'emulator-5554' }
$receipt = $null
$rejected = $false
try { $receipt = Restore-MonkeySystemPanel -Serial $serial } catch { $rejected = $true }
[ordered]@{receipt=$receipt;rejected=$rejected;calls=$script:calls;sourceRoot=$projectRoot} | ConvertTo-Json -Depth 6 -Compress
'''
            .replaceAll('__SCENARIO__', psLiteral(jsonEncode(scenario))),
      );
      final data = output(result);
      expect(data['sourceRoot'], temporaryDirectory.path);
      expect(data['rejected'], scenario['rejected'] ?? false);
      expect(data['calls'], scenario['calls']);
      if (scenario['rejected'] != true) {
        final receipt = data['receipt'] as Map<String, dynamic>;
        expect(receipt['Passed'], scenario['passed']);
        expect(receipt['Collapsed'], scenario['collapsed']);
      }
    });
  }
}
