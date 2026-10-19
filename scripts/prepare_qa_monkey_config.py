"""Derive only QA Monkey package identity from immutable application config."""
import argparse
import copy
import hashlib
import json
from pathlib import Path
import re
import subprocess

BASE = 'com.ghostheart5.chronospark'
QA = BASE + '.qa'
SEEDS = {'priority8-learned-lifecycle.yaml', 'priority8-learned-lifecycle-readback.yaml'}
JOURNEY_FLOWS = ['04-smart-planner.yaml', '05-creator.yaml', '06-si-console.yaml', '07-timeline.yaml', '08-progression.yaml', '09-settings.yaml', '10-subscription-containment.yaml', '11-logout.yaml', 'priority8-account-isolation.yaml', 'priority8-learned-lifecycle.yaml', 'priority8-learned-lifecycle-readback.yaml']


def require(ok, message):
    if not ok:
        raise ValueError(message)


def sha(path):
    digest = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            digest.update(block)
    return digest.hexdigest()


def git(root, *args):
    return subprocess.check_output(['git', '-C', str(root), *args], timeout=30)


def package_from_badging(text):
    matches = re.findall(r"^package: name='([^']+)'(?: |$)", text, re.M)
    require(matches == [QA], 'Exact APK must identify only the QA package')
    return matches[0]


def find_aapt(sdk):
    candidates = []
    for folder in (Path(sdk) / 'build-tools').iterdir():
        if re.fullmatch(r'[0-9]+(?:[.][0-9]+)*', folder.name):
            tool = folder / 'aapt'
            if tool.is_file():
                candidates.append((tuple(map(int, folder.name.split('.'))), tool))
    require(bool(candidates), 'Installed native Android aapt is required')
    return max(candidates)[1]


def derive(config, package):
    require(package == QA, 'QA package required; no production fallback')
    require(config['monkey']['package'] == BASE, 'Immutable source package must be the base package')
    result = copy.deepcopy(config)
    result['monkey']['package'] = QA
    return result


def evidence(root, source, apk, seed_only):
    require(re.fullmatch(r'[a-f0-9]{40}', source) is not None, 'Immutable source SHA required')
    require(git(root, 'rev-parse', 'HEAD').decode().strip() == source, 'Source HEAD mismatch')
    require(not git(root, 'status', '--porcelain=v1', '--untracked-files=all').strip(), 'Source tree must be clean')
    original = git(root, 'show', source + ':test-orchestrator.json')
    config_path = root / 'test-orchestrator.json'
    # Git blob comparison tolerates checkout newline conversion, never content drift.
    require(config_path.read_bytes().replace(b'\r\n', b'\n') == original.replace(b'\r\n', b'\n'), 'Source config content differs')
    config = json.loads(original)
    digest = sha(apk)
    completion_path = root / 'test-results/maestro-prewarm/completion.json'
    completion = json.loads(completion_path.read_text())
    require(completion['sourceSha'] == source and completion['precompiledApkSha256'].lower() == digest and completion['buildExitCode'] == 0 and completion['gradleStopExitCode'] == 0, 'Precompile identity mismatch')
    seed_root = root / ('test-results/monkey-seed-ci' if seed_only else 'artifacts/maestro-ci')
    paths = sorted(seed_root.glob('*/manifest.json'))
    require(len(paths) == (2 if seed_only else 1), 'Expected exact seed receipt count')
    names = []
    receipts = []
    for path in paths:
        item = json.loads(path.read_text(encoding='utf-8-sig'))
        require(item['status'] == 'passed' and item['git']['commit'] == source and not item['git']['dirty'], 'Seed source/status mismatch')
        require(item['apk']['sha256'].lower() == digest and item['installedPackage']['name'] == QA and item['buildProfile'] == 'qa', 'Seed APK/package mismatch')
        require(item['junit']['failures'] == item['junit']['errors'] == item['junit']['skipped'] == 0 and item['fatalMarkerCount'] == 0 and item['logcatCapture']['aliveThroughRun'], 'Seed runtime evidence failed')
        if seed_only:
            require(item['apk']['externalHashVerified'] and item['junit']['testCases'] == 1 and len(item['flows']) == 1, 'Separate seed must be exactly one external-hash-verified test')
        else:
            require(item['suite'] == 'qa-journeys' and item['flows'] == JOURNEY_FLOWS and item['junit']['testCases'] == len(JOURNEY_FLOWS), 'Combined receipt must match the complete ordered QA journey suite')
        names.extend(name for name in item['flows'] if name in SEEDS)
        receipts.append({'path': path.relative_to(root).as_posix(), 'sha256': sha(path)})
    require(len(names) == 2 and set(names) == SEEDS, 'Both exact seed flows required once')
    return config, {'sourceSha': source, 'sourceConfigBlobSha256': hashlib.sha256(original).hexdigest(), 'sourceConfigCheckoutSha256': sha(config_path), 'apkSha256': digest, 'completionSha256': sha(completion_path), 'seedOnly': seed_only, 'seedReceipts': receipts}


def prepare(root, source, target, apk, aapt, seed_only):
    root = Path(root).resolve()
    target = Path(target).resolve()
    require(target != root / 'test-results' and target.is_relative_to(root / 'test-results'), 'Output must be an owned test-results child')
    require(not target.exists(), 'Never overwrite config evidence')
    require(git(root, 'check-ignore', str(target / 'config.json')).strip(), 'Output must be Git-ignored')
    config, receipt = evidence(root, source, Path(apk), seed_only)
    before = sha(Path(apk))
    output = subprocess.run([str(aapt), 'dump', 'badging', str(apk)], check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=30).stdout
    require(len(output) <= 1024 * 1024, 'Unbounded APK metadata output')
    package = package_from_badging(output.decode('utf-8', errors='strict'))
    require(sha(Path(apk)) == before == receipt['apkSha256'], 'APK changed during metadata verification')
    result = derive(config, package)
    receipt.update({'package': package, 'aaptPath': str(aapt), 'aaptSha256': sha(Path(aapt)), 'badgingSha256': hashlib.sha256(output).hexdigest(), 'changedField': 'monkey.package'})
    target.mkdir(parents=True, exist_ok=False)
    config_path = target / 'config.json'
    config_path.write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
    receipt['derivedConfigSha256'] = sha(config_path)
    (target / 'provenance.json').write_text(json.dumps(receipt, indent=2) + '\n', encoding='utf-8')
    return receipt


def verify(root, source, target, apk, seed_only):
    root = Path(root).resolve()
    target = Path(target).resolve()
    require(target != root / 'test-results' and target.is_relative_to(root / 'test-results'), 'Invalid evidence path')
    require({p.name for p in target.iterdir()} == {'config.json', 'provenance.json'}, 'Unexpected config evidence files')
    config, current = evidence(root, source, Path(apk), seed_only)
    receipt = json.loads((target / 'provenance.json').read_text())
    require(all(receipt[k] == v for k, v in current.items()), 'Source/APK/seed provenance drift')
    require(receipt['package'] == QA and receipt['changedField'] == 'monkey.package', 'Wrong derived package')
    require(sha(target / 'config.json') == receipt['derivedConfigSha256'] and json.loads((target / 'config.json').read_text()) == derive(config, QA), 'Derived config altered beyond package mapping')
    require(sha(Path(receipt['aaptPath'])) == receipt['aaptSha256'], 'APK metadata tool changed')
    return receipt


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--verify', action='store_true')
    parser.add_argument('--seed-only', action='store_true')
    parser.add_argument('--sdk')
    for key in ('root', 'source', 'target', 'apk'):
        parser.add_argument('--' + key, required=True)
    args = parser.parse_args()
    if args.verify:
        verify(args.root, args.source, args.target, args.apk, args.seed_only)
    else:
        require(args.sdk is not None, 'Installed SDK is required')
        prepare(args.root, args.source, args.target, args.apk, find_aapt(args.sdk), args.seed_only)
