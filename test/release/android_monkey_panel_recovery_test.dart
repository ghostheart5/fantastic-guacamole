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
      'calls': 5,
      'ownershipVerified': true,
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
      'calls': 4,
    },
    'fails a timed out collapse': {
      'focus': 'mCurrentFocus=Window{6d8f6c u0 NotificationShade}',
      'collapseTimeout': true,
      'passed': false,
      'collapsed': false,
      'calls': 4,
    },
    'verified shade that persists after collapse receives bounded BACK': {
      'focus': 'mCurrentFocus=Window{6d8f6c u0 NotificationShade}',
      'shadeCollapseSticks': true,
      'passed': true,
      'collapsed': true,
      'ownershipVerified': true,
      'backCount': 1,
      'calls': 6,
    },
    'app-owned shade lookalike never receives recovery commands': {
      'focus': 'mCurrentFocus=Window{6d8f6c u0 NotificationShade}',
      'owner': 'com.ghostheart5.chronospark',
      'passed': false,
      'collapsed': false,
      'calls': 2,
    },
    'prefix-owner shade lookalike never receives recovery commands': {
      'focus': 'mCurrentFocus=Window{6d8f6c u0 NotificationShade}',
      'owner': 'com.android.systemui.fake',
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
$script:collapseCount = 0
$script:backCount = 0
function Invoke-Adb {
    param([string[]]$Arguments, [int]$TimeoutMilliseconds)
    $script:calls++
    $command = $Arguments -join ' '
    if ($command -match 'dumpsys window displays') {
        $focus = if ($script:collapseCount -gt 0 -and -not $script:scenario.shadeCollapseSticks) {
            'mCurrentFocus=Window{app u0 com.ghostheart5.chronospark/.MainActivity}'
        } else { $script:scenario.focus }
        return [pscustomobject]@{Output=@($focus);ExitCode=[int]$script:scenario.windowExit;TimedOut=[bool]$script:scenario.windowTimeout}
    }
    if ($command -match 'dumpsys window windows') {
        $owner = if ($script:scenario.owner) { $script:scenario.owner } else { 'com.android.systemui' }
        return [pscustomobject]@{Output=@("Window #0 Window{6d8f6c u0 NotificationShade}:`n  package=$owner appop=NONE");ExitCode=0;TimedOut=$false}
    }
    if ($command -match 'cmd statusbar collapse') {
        $script:collapseCount++
        return [pscustomobject]@{Output=@();ExitCode=[int]$script:scenario.collapseExit;TimedOut=[bool]$script:scenario.collapseTimeout}
    }
    if ($command -match 'input keyevent KEYCODE_BACK') {
        $script:backCount++
        return [pscustomobject]@{Output=@();ExitCode=0;TimedOut=$false}
    }
    throw "Unexpected command: $command"
}
$serial = if ($script:scenario.serial) { $script:scenario.serial } else { 'emulator-5554' }
$receipt = $null
$rejected = $false
try { $receipt = Restore-MonkeySystemPanel -Serial $serial } catch { $rejected = $true }
[ordered]@{receipt=$receipt;rejected=$rejected;calls=$script:calls;backCount=$script:backCount;sourceRoot=$projectRoot} | ConvertTo-Json -Depth 6 -Compress
'''
            .replaceAll('__SCENARIO__', psLiteral(jsonEncode(scenario))),
      );
      final data = output(result);
      expect(data['sourceRoot'], temporaryDirectory.path);
      expect(data['rejected'], scenario['rejected'] ?? false);
      expect(data['calls'], scenario['calls']);
      expect(data['backCount'], scenario['backCount'] ?? 0);
      if (scenario['rejected'] != true) {
        final receipt = data['receipt'] as Map<String, dynamic>;
        expect(receipt['Passed'], scenario['passed']);
        expect(receipt['Collapsed'], scenario['collapsed']);
        if (scenario.containsKey('ownershipVerified')) {
          expect(receipt['OwnershipVerified'], scenario['ownershipVerified']);
        }
      }
    });
  }
}
