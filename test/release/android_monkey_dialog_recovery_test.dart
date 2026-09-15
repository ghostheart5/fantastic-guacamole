import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory temporary;
  setUpAll(
    () =>
        temporary = Directory.systemTemp.createTempSync('chronospark-dialog-'),
  );
  tearDownAll(() => temporary.deleteSync(recursive: true));
  String literal(String value) => "'${value.replaceAll("'", "''")}'";

  Map<String, dynamic> run(Map<String, Object> scenario, {bool probe = false}) {
    final script = File('${temporary.path}/fixture.ps1');
    script.writeAsStringSync('''\ufeff
\$ErrorActionPreference = 'Stop'
. ${literal(File('scripts/run_android_monkey_matrix.ps1').absolute.path)}
\$script:case = ${literal(jsonEncode(scenario))} | ConvertFrom-Json
\$script:backCount = 0
\$script:focusReadsAfterBack = 0
\$script:totalFocusReads = 0
\$script:commands = @()
function Invoke-Adb {
  param([string[]]\$Arguments, [int]\$TimeoutMilliseconds)
  \$command = \$Arguments -join ' '
  \$script:commands += \$command
  \$output = @(); \$exit = 0; \$timedOut = \$false
  if (\$command -match 'pidof') { \$output = @('9717') }
  elseif (\$command -match 'dumpsys window windows') {
    \$owner = if (\$script:case.owner) { \$script:case.owner } elseif (\$script:case.voice) { 'com.google.android.googlequicksearchbox' } else { 'com.android.systemui' }
    \$title = if (\$script:case.voice) { 'VoiceInteractionSession' } else { 'SystemUIDialog' }
    \$output = @("  Window #0 Window{abc u0 \$title}:`n    mOwnerUid=1000 package=\$owner appop=NONE`n  Window #1 Window{other u0 StatusBar}:`n    package=com.android.systemui appop=NONE")
    \$exit = [int]\$script:case.windowExit
    \$timedOut = [bool]\$script:case.windowTimeout
  }
  elseif (\$command -match 'dumpsys window displays') {
    \$script:totalFocusReads++
    if (\$script:case.late -and \$script:totalFocusReads -eq 1) {
      \$output = @('mCurrentFocus=Window{app u0 com.ghostheart5.chronospark/.MainActivity}')
    } elseif (\$script:case.focusChangesDuringRecovery -and \$script:totalFocusReads -gt 1) {
      \$output = @('mCurrentFocus=Window{app u0 com.ghostheart5.chronospark/.MainActivity}')
    } elseif (\$script:backCount -gt 0 -and -not \$script:case.persistent) {
      \$script:focusReadsAfterBack++
      \$output = @('mCurrentFocus=Window{app u0 com.ghostheart5.chronospark/.MainActivity}')
    } elseif (\$script:case.changedFocus) { \$output = @('mCurrentFocus=Window{app u0 com.ghostheart5.chronospark/.MainActivity}') }
    else { \$output = @(\$script:case.focus) }
  }
  elseif (\$command -match 'input keyevent KEYCODE_BACK') { \$script:backCount++; \$exit = [int]\$script:case.backExit }
  else { throw "Unexpected command: \$command" }
  [pscustomobject]@{Output=\$output;ExitCode=\$exit;TimedOut=\$timedOut}
}
\$serial = if (\$script:case.serial) { \$script:case.serial } else { 'emulator-5554' }
\$receipt = \$null; \$rejected = \$false
try {
  ${probe ? r'$receipt = Wait-ForPackageFocus -Serial $serial -PackageName com.ghostheart5.chronospark -TimeoutSeconds 2 -PollMilliseconds 100 -RecoverSystemDialogs' : r'$receipt = if ($script:case.voice) { Restore-MonkeyVoiceSession -Serial $serial -ExpectedFocus $script:case.focus } else { Restore-MonkeySystemDialog -Serial $serial -ExpectedFocus $script:case.focus }'}
} catch { \$rejected = \$true }
[ordered]@{receipt=\$receipt;rejected=\$rejected;backCount=\$script:backCount;focusReadsAfterBack=\$script:focusReadsAfterBack;commands=\$script:commands} | ConvertTo-Json -Depth 12 -Compress
''');
    final result = Process.runSync(
      Platform.isWindows ? 'powershell.exe' : 'pwsh',
      [
        '-NoProfile',
        '-NonInteractive',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        script.path,
      ],
    );
    expect(result.exitCode, 0, reason: '${result.stderr}');
    return jsonDecode(result.stdout as String) as Map<String, dynamic>;
  }

  const dialog = 'mCurrentFocus=Window{abc u0 SystemUIDialog}';
  const voice = 'mCurrentFocus=Window{abc u0 VoiceInteractionSession}';
  test('cancels verified Android dialog and records ownership evidence', () {
    final data = run({'focus': dialog});
    expect(data['backCount'], 1);
    expect((data['receipt'] as Map<String, dynamic>)['Passed'], isTrue);
    expect(
      (data['receipt'] as Map<String, dynamic>)['Windows'],
      contains('package=com.android.systemui'),
    );
    expect((data['receipt'] as Map<String, dynamic>)['Commands'], hasLength(3));
  });
  test(
    'cancels a verified Android assistant overlay then probes app focus',
    () {
      final data = run({'focus': voice, 'voice': true}, probe: true);
      expect(data['backCount'], 1);
      final receipt = data['receipt'] as Map<String, dynamic>;
      expect(receipt['Ready'], isTrue);
      final samples = (receipt['ProbeSamples'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      expect(samples.last['stableSamples'], 2);
      expect(samples.last['validFocus'], isTrue);
      expect(
        (samples.firstWhere(
              (s) => s['systemDialogRecovery'] != null,
            )['systemDialogRecovery']
            as Map<String, dynamic>)['Windows'],
        contains('package=com.google.android.googlequicksearchbox'),
      );
    },
  );
  test('assistant lookalikes never receive BACK', () {
    for (final owner in <String>[
      'com.ghostheart5.chronospark',
      'com.google.android.googlequicksearchbox.fake',
    ]) {
      final data = run({'focus': voice, 'voice': true, 'owner': owner});
      expect(data['backCount'], 0);
      expect((data['receipt'] as Map<String, dynamic>)['Passed'], isFalse);
    }
  });
  test('assistant focus change sends no key and needs stable app probes', () {
    final data = run({
      'focus': voice,
      'voice': true,
      'focusChangesDuringRecovery': true,
    }, probe: true);
    expect(data['backCount'], 0);
    final receipt = data['receipt'] as Map<String, dynamic>;
    expect(receipt['Ready'], isTrue);
    final samples = (receipt['ProbeSamples'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    expect(samples.last['stableSamples'], 2);
  });
  for (final entry in <String, Map<String, Object>>{
    'app-owned lookalike': {
      'focus': dialog,
      'owner': 'com.ghostheart5.chronospark',
    },
    'package-prefix lookalike': {
      'focus': dialog,
      'owner': 'com.android.systemui.fake',
    },
    'changed foreground': {'focus': dialog, 'changedFocus': true},
    'failed ownership read': {'focus': dialog, 'windowExit': 1},
    'ownership read timeout': {'focus': dialog, 'windowTimeout': true},
    'ANR dialog': {
      'focus':
          'mCurrentFocus=Window{abc u0 Application Not Responding: com.ghostheart5.chronospark}',
    },
    'app screen': {
      'focus':
          'mCurrentFocus=Window{abc u0 com.ghostheart5.chronospark/.MainActivity}',
    },
  }.entries) {
    test('does not send BACK for ${entry.key}', () {
      final data = run(entry.value);
      expect(data['backCount'], 0);
      expect((data['receipt'] as Map<String, dynamic>)['Passed'], isFalse);
    });
  }
  test('refuses physical phones before any ADB call', () {
    final data = run({'focus': dialog, 'serial': '192.168.1.174:37567'});
    expect(data['rejected'], isTrue);
    expect(data['commands'], isEmpty);
  });
  test('failed BACK cannot become a successful recovery', () {
    final data = run({'focus': dialog, 'backExit': 1}, probe: true);
    expect(data['backCount'], 1);
    expect((data['receipt'] as Map<String, dynamic>)['Ready'], isFalse);
  });
  test('disappearing SystemUI dialog requires two stable app probes', () {
    final data = run({
      'focus': dialog,
      'focusChangesDuringRecovery': true,
    }, probe: true);
    expect((data['receipt'] as Map<String, dynamic>)['Ready'], isTrue);
    expect(data['backCount'], 0);
    final samples =
        ((data['receipt'] as Map<String, dynamic>)['ProbeSamples']
                as List<dynamic>)
            .cast<Map<String, dynamic>>();
    final recovery =
        samples.firstWhere(
              (sample) => sample['systemDialogRecovery'] != null,
            )['systemDialogRecovery']
            as Map<String, dynamic>;
    expect(recovery['Passed'], isFalse);
    expect(
      recovery['Reason'],
      'Focus changed before recovery; no key was sent.',
    );
    expect(samples.last['stableSamples'], 2);
    expect(samples.last['validFocus'], isTrue);
  });
  test('late system dialog recovery still requires two stable app probes', () {
    final data = run({'focus': dialog, 'late': true}, probe: true);
    expect((data['receipt'] as Map<String, dynamic>)['Ready'], isTrue);
    expect(data['backCount'], 1);
    expect(data['focusReadsAfterBack'], 2);
    final samples =
        ((data['receipt'] as Map<String, dynamic>)['ProbeSamples']
                as List<dynamic>)
            .cast<Map<String, dynamic>>();
    expect(
      (samples.firstWhere(
            (s) => s['systemDialogRecovery'] != null,
          )['systemDialogRecovery']
          as Map<String, dynamic>)['Passed'],
      isTrue,
    );
    expect(samples.first['stableSamples'], 1);
    expect(samples.last['stableSamples'], 2);
  });
  test('persistent dialogs cannot create an unbounded dismissal loop', () {
    final data = run({'focus': dialog, 'persistent': true}, probe: true);
    expect((data['receipt'] as Map<String, dynamic>)['Ready'], isFalse);
    expect(data['backCount'], 2);
  });
}
