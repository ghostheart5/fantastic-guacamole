"""Validate real hosted gate receipts, or retain disposable-emulator UI snapshots."""
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import xml.etree.ElementTree as ET

SOURCE = '43b7065507e41f11e6cb31628f928e985e4307d2'
FLOWS = ['04-smart-planner.yaml','05-creator.yaml','06-si-console.yaml','07-timeline.yaml','08-progression.yaml','09-settings.yaml','10-subscription-containment.yaml','11-logout.yaml','priority8-account-isolation.yaml','priority8-learned-lifecycle.yaml','priority8-learned-lifecycle-readback.yaml']

def require(value, message):
    if not value:
        raise ValueError(message)

def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))

def digest(path):
    h = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1048576), b''):
            h.update(block)
    return h.hexdigest()

def one_manifest(root):
    paths = list(root.glob('*/manifest.json'))
    require(len(paths) == 1, 'Expected exactly one terminal manifest: ' + str(root))
    return paths[0], read(paths[0])

def maestro(root, expected_flows, apk_hash):
    path, m = one_manifest(root)
    require(m['status'] == 'passed' and m['git']['commit'] == SOURCE and not m['git']['dirty'], 'Maestro source/status mismatch')
    require(m['apk']['sha256'].lower() == apk_hash and m['flows'] == expected_flows, 'Maestro APK/flow mismatch')
    require(m['maestroExitCode'] == 0 and not m['maestro']['timedOut'], 'Maestro process failed')
    require(m['fatalMarkerCount'] == 0, 'Maestro fatal runtime markers')
    c = m['logcatCapture']
    require(c['status'] == 'passed' and c['aliveThroughRun'] and c['outputBytes'] > 0 and c['stderrBytes'] == 0, 'Incomplete Logcat capture')
    j = m['junit']
    require(j['terminalParsed'] and j['status'] == 'passed' and j['testCases'] == len(expected_flows) and j['testCaseCountMatchesFlows'], 'Incomplete Maestro JUnit')
    require(j['failures'] == j['errors'] == j['skipped'] == 0, 'Nonpassing Maestro cases')
    xml = ET.parse(path.parent / 'maestro-results.xml')
    cases = xml.findall('.//testcase')
    require(len(cases) == len(expected_flows), 'JUnit testcase count mismatch')
    require(sorted(c.get('name') for c in cases) == sorted(Path(f).stem for f in expected_flows), 'JUnit testcase names mismatch')
    require(not any(xml.findall('.//' + tag) for tag in ('failure','error','skipped')), 'Actual JUnit contains nonpassing cases')
    return {'tests': len(cases), 'manifestSha256': digest(path), 'junitSha256': digest(path.parent / 'maestro-results.xml')}

def monkey(root, config, apk_hash):
    path, m = one_manifest(root)
    variants = config['monkey']['variants']
    require(m['status'] == 'passed' and m['git']['commit'] == SOURCE and not m['git']['dirty'], 'Monkey source/status mismatch')
    require(m['apk']['sha256'].lower() == apk_hash and m['apk']['installExitCode'] == 0 and not m['apk']['installTimedOut'], 'Monkey APK install mismatch')
    require(m['device']['serial'] == 'emulator-5554' and str(m['device']['androidApi']) == '35', 'Monkey device mismatch')
    require(m['completedVariantCount'] == m['requestedVariantCount'] == len(variants) == len(m['results']), 'Incomplete Monkey matrix')
    count = 0
    for result, expected in zip(m['results'], variants):
        for key in ('name','seed','events','throttleMs','percentages'):
            require(result[key] == expected[key], 'Monkey configuration changed: ' + key)
        require(result['status'] == 'passed' and result['monkeyExitCode'] == 0 and not result['monkeyTimedOut'], 'Monkey process failed')
        require(result['injectedEvents'] == result['requestedEvents'] == expected['events'] and result['eventCountVerified'], 'Monkey event count mismatch')
        require(result['startupReady'] and result['logcatCollected'] and result['fatalMarkerCount'] == 0 and result['relaunchSucceeded'] and result['relaunchProcessAbsent'], 'Monkey readiness/capture/relaunch failed')
        count += result['injectedEvents']
    return {'variants': len(variants), 'injectedEvents': count, 'manifestSha256': digest(path)}

def verify(root, controls):
    m = read(root / 'campaign-manifest.json')
    require(m['status'] == 'passed' and m['sourceCommit'] == SOURCE and m['sourceCleanAfter'], 'Campaign not complete/passing')
    require([s['name'] for s in m['steps']] == ['journeys','baseline-monkey','expanded-monkey','welcome'], 'Campaign stage inventory mismatch')
    require(all(s['exitCode'] == 0 and s['status'] == 'passed' for s in m['steps']), 'Campaign stage failed')
    apk = root / 'qa.apk'
    apk_hash = digest(apk)
    require(apk_hash == m['apk']['sha256'] and apk.stat().st_size == m['apk']['bytes'], 'Retained APK mismatch')
    require(apk_hash == 'af2f8d4ffb8b2af3e80f4b06b873ed4b40d3fb5e333af35bf1c8e53cad899d38', 'Recheck did not retain original hosted APK')
    import importlib.util
    spec = importlib.util.spec_from_file_location('campaign_flow_preparation', controls / 'prepare_flow.py')
    preparation = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(preparation)
    original = (root / 'controls/original-priority8-learned-lifecycle.yaml').read_text(encoding='utf-8')
    executed = (root / 'controls/executed-priority8-learned-lifecycle.yaml').read_text(encoding='utf-8')
    require(executed == preparation.adjusted(original), 'Execution flow has unexpected changes')
    override = read(root / 'flow-override.json')
    require(override['originalCanonicalSha256'] == preparation.digest(original) and override['executionCanonicalSha256'] == preparation.digest(executed), 'Flow override receipt mismatch')
    result = {'status':'passed', 'sourceCommit':SOURCE, 'harnessCommit':m['harnessCommit'], 'runId':m['runId'], 'attempt':m['attempt'], 'apkSha256':apk_hash}
    result['journeys'] = maestro(root / 'maestro', FLOWS, apk_hash)
    result['baselineMonkey'] = monkey(root / 'baseline-monkey', read(controls / 'baseline.json'), apk_hash)
    result['expandedMonkey'] = monkey(root / 'expanded-monkey', read(controls / 'expanded.json'), apk_hash)
    require(result['baselineMonkey']['injectedEvents'] == 1700 and result['expandedMonkey']['injectedEvents'] == 8750, 'Total planned stress counts changed')
    result['welcome'] = maestro(root / 'welcome', ['03-onboarding-tutorial.yaml'], apk_hash)
    result['verifiedAtUtc'] = datetime.now(timezone.utc).isoformat()
    return result

def snapshot(root, label):
    require(label in ('before-baseline','after-baseline','after-expanded'), 'Unknown snapshot label')
    def adb(*args):
        return subprocess.run(['adb','-s','emulator-5554',*args],capture_output=True,check=True,timeout=25).stdout
    require(adb('shell','getprop','ro.build.version.sdk').strip() == b'35', 'Wrong snapshot device API')
    destination = root / 'snapshots'
    destination.mkdir(exist_ok=True)
    png = adb('exec-out','screencap','-p')
    require(png.startswith(b'\x89PNG\r\n\x1a\n'), 'Invalid actual screenshot')
    (destination / (label + '.png')).write_bytes(png)
    remote = '/sdcard/chronospark-hosted-campaign-' + label + '.xml'
    adb('shell','uiautomator','dump',remote)
    try:
        (destination / (label + '.xml')).write_bytes(adb('exec-out','cat',remote))
    finally:
        adb('shell','rm',remote)

if __name__ == '__main__':
    if len(sys.argv) == 4 and sys.argv[1] == '--snapshot':
        snapshot(Path(sys.argv[2]), sys.argv[3])
    else:
        root = Path(sys.argv[1])
        controls = Path(sys.argv[2]) if len(sys.argv) > 2 else Path(__file__).resolve().parent
        try:
            result = verify(root, controls)
        except Exception as error:
            result = {'status':'failed','sourceCommit':SOURCE,'error':str(error),'verifiedAtUtc':datetime.now(timezone.utc).isoformat()}
        root.mkdir(parents=True, exist_ok=True)
        (root / 'verification.json').write_text(json.dumps(result,indent=2) + '\n',encoding='utf-8')
        print(json.dumps(result,indent=2))
        raise SystemExit(0 if result['status'] == 'passed' else 1)
