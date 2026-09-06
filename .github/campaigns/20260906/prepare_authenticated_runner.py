"""Retain a narrowly extended test runner while leaving its source file unchanged."""
import hashlib
import json
from pathlib import Path
import shutil
import sys

SOURCE_HASH = '20a18d58a1e14e39f17175e7a7ba3c5e9ae9a9f8dec26ced60e3f3e37c368ba8'
ROOT_LINE = "$projectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path"
MONKEY_LINE = '    $monkeyArgs = [System.Collections.Generic.List[string]]::new()'
LOG_LINE = '    $logcatText = $logcatResult.Output -join "`n"'
AUTH = '''    $authenticatedStartVerified = $false
    if ($startupReadiness.Ready) {
        & python3 $env:CHRONOSPARK_STRESS_BOOTSTRAP --source $projectRoot --output $runRoot --name $name --serial $serial
        if ($LASTEXITCODE -ne 0) { throw "Authenticated UI readiness failed before '$name'; no stress events started." }
        $authenticatedStartVerified = $true
    }

'''
REPLACEMENTS = [
    (ROOT_LINE, '$projectRoot = (Resolve-Path -LiteralPath $env:CHRONOSPARK_FROZEN_SOURCE).Path'),
    (MONKEY_LINE, AUTH + MONKEY_LINE),
    (LOG_LINE, LOG_LINE + '\n    $logcatText | Set-Content -LiteralPath (Join-Path $runRoot "$name-full-logcat.log") -Encoding utf8'),
    ('        startupReady = $startupReadiness.Ready', '        authenticatedStartVerified = $authenticatedStartVerified\n        startupReady = $startupReadiness.Ready'),
]

def digest(text):
    return hashlib.sha256(text.encode('utf-8')).hexdigest()

def adjusted(original):
    if digest(original) != SOURCE_HASH:
        raise ValueError('Original maintained Monkey runner changed')
    changed = original
    for before, after in REPLACEMENTS:
        if changed.count(before) != 1:
            raise ValueError('A required exact extension point is missing or ambiguous')
        changed = changed.replace(before,after)
    reversed_text = changed
    for before, after in reversed(REPLACEMENTS):
        reversed_text = reversed_text.replace(after,before,1)
    if reversed_text != original:
        raise ValueError('Unexpected modification outside the four test-harness extensions')
    return changed

def prepare(source):
    original = (source/'scripts/run_android_monkey_matrix.ps1').read_text(encoding='utf-8')
    changed = adjusted(original)
    folder = source/'test-results/authenticated-runner/scripts'
    folder.mkdir(parents=True,exist_ok=False)
    (folder/'run_android_monkey_matrix.ps1').write_text(changed,encoding='utf-8')
    shutil.copyfile(source/'scripts/android_runtime_fatal_patterns.ps1',folder/'android_runtime_fatal_patterns.ps1')
    campaign = source/'test-results/hosted-campaign'
    (campaign/'controls/original-monkey-runner.ps1').write_text(original,encoding='utf-8')
    (campaign/'controls/executed-monkey-runner.ps1').write_text(changed,encoding='utf-8')
    receipt = {'originalCanonicalSha256':digest(original),'executedCanonicalSha256':digest(changed),
               'applicationSourceChanged':False,'originalEventAndRuntimeGatesPreserved':True,
               'extensions':['explicit frozen source root for isolated copy','Nexus UI bootstrap before each ready variant',
                             'retain full per-variant Logcat','record authenticated-start result']}
    (campaign/'runner-extension.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(receipt))

if __name__=='__main__':
    prepare(Path(sys.argv[1]))
