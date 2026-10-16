"""Verify the reviewed overlay and fail closed on incomplete CI evidence.

Standard library only. This helper never installs dependencies, invokes an SDK,
contacts a service, or stages/commits source. Only apply writes the reviewed patch.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import subprocess
import sys

PREFIX = 'ci/qa-review'
SOURCE = '5bcdef1b47ca265a2e3069d7702603db26afa85f'
BASE = '8780c538ad9ba9744c37c16411961e98b1f4e2b3'
BRANCH = 'test/axiomara-export-review-20261016'
OUTCOMES = ('FORMAT_OUTCOME', 'ANALYSIS_OUTCOME', 'MAESTRO_OUTCOME',
            'CLOUD_OUTCOME', 'LOCAL_OUTCOME', 'DEPS_OUTCOME', 'FLUTTER_OUTCOME')
MAX_LOG = 16 * 1024 * 1024


class GateError(Exception):
    pass


def need(condition, message):
    if not condition:
        raise GateError(message)


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def json_file(path, maximum=1024 * 1024):
    path = Path(path)
    need(path.is_file() and 0 < path.stat().st_size <= maximum,
         f'Missing, empty or oversized JSON: {path.name}')
    value = json.loads(path.read_text(encoding='utf-8'))
    need(type(value) is dict, f'JSON object required: {path.name}')
    return value


def git(root, *arguments):
    env = dict(os.environ, GIT_OPTIONAL_LOCKS='0', GIT_TERMINAL_PROMPT='0')
    result = subprocess.run(['git', '--no-optional-locks', '-C', str(root),
                             *arguments], capture_output=True, timeout=30, env=env)
    need(result.returncode == 0,
         'Git identity/patch check failed: ' + ' '.join(arguments))
    return result.stdout


def load_manifest(payload):
    path = payload / PREFIX / 'candidate-manifest.json'
    expected = os.environ.get('MANIFEST_SHA256', '')
    need(re.fullmatch(r'[0-9a-f]{64}', expected) is not None,
         'Missing pinned manifest hash')
    need(sha(path) == expected, 'Payload manifest hash mismatch')
    m = json_file(path)
    need(m['sourceCommit'] == SOURCE and m['workflowBaseCommit'] == BASE,
         'Source/workflow base mismatch')
    need(m['workflowBranch'] == BRANCH, 'Workflow branch mismatch')
    need(m['countsAreSourceEstimate'] is True and m['allowedSkips'] == 0,
         'Manifest scope mismatch')
    paths = m['modifiedTracked'] + m['untrackedAdded']
    need(len(paths) == 14 and len(set(paths)) == 14,
         'Fourteen unique reviewed source files required')
    need(set(paths) == set(m['fileSha256']), 'File map must exactly cover overlay')
    for name in paths:
        p = PurePosixPath(name)
        need(not p.is_absolute() and '..' not in p.parts,
             'Unsafe source path')
    need(len(m['modifiedTracked']) == 9 and len(m['untrackedAdded']) == 5,
         'Expected nine modified and five added files')
    return m


def verify_payload(payload, m, workflow_sha):
    need(re.fullmatch(r'[0-9a-f]{40}', workflow_sha) is not None,
         'Exact workflow commit required')
    need(git(payload, 'rev-parse', 'HEAD').decode().strip() == workflow_sha,
         'Workflow payload HEAD mismatch')
    need(git(payload, 'rev-parse', 'HEAD^').decode().strip() == BASE,
         'Publish exactly one reviewed payload commit on the frozen base')
    need(not git(payload, 'status', '--porcelain=v1', '--untracked-files=all').strip(),
         'Workflow payload must remain clean')
    changed = set(git(payload, 'diff', '--name-only', '--no-renames', BASE, 'HEAD')
                  .decode().splitlines())
    need(changed == set(m['publishPaths']), 'Unexpected workflow-branch changes')
    need(sha(payload / PREFIX / 'FULL_CANDIDATE_FINAL.patch') ==
         m['overlayPatchSha256'], 'Overlay patch hash mismatch')
    need(sha(payload / PREFIX / 'verify_candidate.py') == m['helperSha256'],
         'Verification helper hash mismatch')
    need(sha(payload / PREFIX / 'build_guard.py') == m['buildGuardSha256'], 'Build guard hash mismatch')
    need(sha(payload / PREFIX / 'manual-storage-clearance.template.json') == m['storageTemplateSha256'], 'Storage template changed')
    for name, expected in m['componentPatchSha256'].items():
        need(sha(payload / PREFIX / name) == expected, 'Component patch changed: ' + name)


def index_hash(source):
    return hashlib.sha256(git(source, 'ls-files', '--stage', '-z')).hexdigest()


def validate_status(raw, m):
    entries = [x.decode('utf-8') for x in raw.split(b'\0') if x]
    expected = {(' M', p) for p in m['modifiedTracked']}
    expected |= {('??', p) for p in m['untrackedAdded']}
    actual = {(x[:2], x[3:]) for x in entries}
    need(len(entries) == 14 and actual == expected,
         'Source status is not the exact nine-modified/five-untracked overlay')


def source_identity(source, m, state=None, clean=False):
    need(git(source, 'rev-parse', 'HEAD').decode().strip() == SOURCE,
         'Application HEAD changed')
    need(not git(source, 'diff', '--cached', '--name-only', 'HEAD').strip(),
         'Source index must still match published HEAD')
    raw = git(source, 'status', '--porcelain=v1', '-z', '--untracked-files=all')
    if clean:
        need(not raw, 'Initial published source must be clean before overlay')
    else:
        validate_status(raw, m)
        for name, expected in m['fileSha256'].items():
            need(sha(source / name) == expected, 'Changed reviewed bytes: ' + name)
    need(sha(source / 'pubspec.lock') == m['lockSha256'], 'Lockfile changed')
    need(sha(source / 'tool/qa_defines.json') == m['qaDefinesSha256'],
         'QA defines changed')
    need(sha(source / '.env.example') == m['envExampleSha256'],
         'Credential-free example changed')
    need(sha(source / 'tool/run_flutter_tests.dart') == m['fixtureRunnerSha256'], 'Maintained fixture runner changed')
    need(sha(source / 'tool/validate_maestro_flows.dart') == m['maestroValidatorSha256'], 'Maintained Maestro validator changed')
    need(git(source, 'rev-parse', 'HEAD^{tree}').decode().strip() == m['baseTreeGitSha1'], 'Base source tree changed')
    if (source / '.env').exists():
        need(sha(source / '.env') == m['envExampleSha256'],
             '.env must exactly equal the credential-free example')
        git(source, 'check-ignore', '-q', '.env')
    result = {'head': SOURCE,
              'tree': git(source, 'rev-parse', 'HEAD^{tree}').decode().strip(),
              'indexEntriesSha256': index_hash(source),
              'overlayPatchSha256': m['overlayPatchSha256'],
              'sourceStackSha256': m['sourceStackSha256'],
              'composedTreeGitSha1': m['composedTreeGitSha1'],
              'lockSha256': m['lockSha256'],
              'qaDefinesSha256': m['qaDefinesSha256'],
              'files': m['fileSha256'] if not clean else {},
              'status': raw.decode('utf-8').replace('\0', '\n')}
    if state is not None:
        for key in ('head', 'tree', 'indexEntriesSha256', 'overlayPatchSha256',
                    'lockSha256', 'qaDefinesSha256'):
            need(result[key] == state[key], 'Source/index identity changed: ' + key)
    return result


def resource_gate(source):
    available = next(int(line.split()[1]) * 1024
                     for line in Path('/proc/meminfo').read_text().splitlines()
                     if line.startswith('MemAvailable:'))
    free = shutil.disk_usage(source).free
    need(available >= 6 * 1024**3, 'At least 6 GiB available RAM required')
    need(free >= 8 * 1024**3, 'At least 8 GiB free disk required')
    return {'availableRamBytes': available, 'freeDiskBytes': free}


def int_equal(value, expected, name):
    need(type(value) is int and value == expected, 'Invalid count/status: ' + name)


def validate_report(manifest, report_text, files, expected, report_path, local):
    need(manifest.get('finalSuccess') is True, 'finalSuccess must be true')
    need(manifest.get('terminalCompletion') is True, 'Terminal completion missing')
    need(manifest.get('terminalSuccess') is True, 'Terminal success false/missing')
    need(manifest.get('timedOut') is False, 'timedOut must be false')
    need(manifest.get('launchFailed') is False, 'launchFailed must be false')
    int_equal(manifest.get('schemaVersion'), 1, 'schemaVersion')
    int_equal(manifest.get('exitCode'), 0, 'exitCode')
    int_equal(manifest.get('allowedSkips'), 0, 'allowedSkips')
    int_equal(manifest.get('timeoutSeconds'), 240, 'timeoutSeconds')
    int_equal(manifest.get('completedTests'), expected, 'completedTests')
    need(type(manifest.get('reportParseErrors')) is list and
         manifest['reportParseErrors'] == [], 'Report parse errors')
    totals = manifest.get('totals')
    need(type(totals) is dict, 'Missing totals')
    for key, value in {'total': expected, 'passed': expected, 'failed': 0,
                       'error': 0, 'skipped': 0}.items():
        int_equal(totals.get(key), value, key)
    need(Path(manifest.get('reportPath', '')).resolve() == report_path.resolve(),
         'Report path mismatch')
    command = manifest.get('command', {})
    expected_args = ['test', *files, '--no-pub', '--concurrency=1',
                     '--reporter', 'expanded']
    if local:
        expected_args.append('--dart-define-from-file=tool/qa_defines.json')
    expected_args += ['--file-reporter', 'json:' + str(report_path)]
    need(command.get('executable') == 'flutter' and
         command.get('arguments') == expected_args,
         'Test selection, serial concurrency or exact QA mode changed')
    need(command.get('launcher') == 'setsid' and
         command.get('isolatedProcessGroup') is True,
         'Expected maintained Linux process-group runner')
    completed = set()
    done_count = 0
    last_type = None
    for line in report_text.splitlines():
        if not line.strip():
            continue
        event = json.loads(line)
        need(type(event) is dict, 'JSONL object required')
        kind = event.get('type')
        last_type = kind
        need(kind != 'error', 'JSONL error event')
        if kind == 'done':
            done_count += 1
            need(event.get('success') is True, 'JSONL done success false/missing')
        if kind != 'testDone' or event.get('hidden') is True:
            continue
        test_id = event.get('testID')
        need(type(test_id) is int and test_id not in completed,
             'Invalid/duplicate visible test ID')
        completed.add(test_id)
        need(event.get('skipped', False) is False and
             event.get('result') == 'success', 'Failed, skipped or incomplete test')
    need(done_count == 1 and last_type == 'done', 'Missing/duplicate/nonfinal done')
    need(len(completed) == expected, 'JSONL visible-case count mismatch')


def verify_outcomes(environment):
    for name in OUTCOMES:
        need(environment.get(name) == 'success', 'Raw step outcome failed: ' + name)


def log_file(path):
    need(path.is_file() and 0 < path.stat().st_size <= MAX_LOG,
         'Missing/empty/oversized evidence: ' + path.name)
    text = path.read_text(encoding='utf-8')
    print('::group::' + path.name, flush=True)
    print(text, end='' if text.endswith('\n') else '\n', flush=True)
    print('::endgroup::', flush=True)
    return text


def capture_logs(paths):
    captured = {}
    errors = []
    for path in paths:
        try:
            captured[path] = log_file(path)
        except (GateError, ValueError, OSError, KeyError, TypeError) as error:
            errors.append(path.name + ': ' + str(error))
    return captured, errors


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('mode', choices=['apply', 'final'])
    parser.add_argument('--source', required=True, type=Path)
    parser.add_argument('--payload', required=True, type=Path)
    parser.add_argument('--evidence', required=True, type=Path)
    parser.add_argument('--workflow-sha', required=True)
    args = parser.parse_args()
    source, payload, evidence = (x.resolve() for x in
                                 (args.source, args.payload, args.evidence))
    need(not evidence.is_relative_to(source) and not evidence.is_relative_to(payload),
         'Evidence must be outside both checkouts')
    m = load_manifest(payload)
    verify_payload(payload, m, args.workflow_sha)
    state_path = evidence / 'candidate-state.json'
    if args.mode == 'apply':
        need(not state_path.exists(), 'Overlay application is one-shot')
        need(not (source / '.env').exists(), 'Unexpected existing .env')
        resource = resource_gate(source)
        state = source_identity(source, m, clean=True)
        patch_path = payload / PREFIX / 'FULL_CANDIDATE_FINAL.patch'
        git(source, 'apply', '--check', '--whitespace=error-all', str(patch_path))
        git(source, 'apply', '--whitespace=error-all', str(patch_path))
        state = source_identity(source, m, state=state)
        state.update(workflowSha=args.workflow_sha, resource=resource,
                     candidateIdentity=SOURCE + '+overlay:' + m['overlayPatchSha256'])
        evidence.mkdir(parents=True, exist_ok=True)
        state_path.write_text(json.dumps(state, indent=2) + '\n', encoding='utf-8')
        print(json.dumps(state), flush=True)
        return 0
    evidence_paths = [evidence / (mode + suffix)
                      for mode in ('cloud', 'local-qa')
                      for suffix in ('.jsonl', '-manifest.json')]
    captured, errors = capture_logs(evidence_paths)
    for mode, local in [('cloud', False), ('local-qa', True)]:
        report_path = evidence / (mode + '.jsonl')
        manifest_path = evidence / (mode + '-manifest.json')
        try:
            need(report_path in captured, 'JSONL report capture failed')
            report_text = captured[report_path]
            manifest = json_file(manifest_path)
            files = m['localQaDartFiles'] if local else m['cloudDartFiles']
            expected = m['expectedCounts']['localQa' if local else 'cloud']
            validate_report(manifest, report_text, files, expected, report_path, local)
        except (GateError, ValueError, OSError, KeyError, TypeError) as error:
            errors.append(mode + ': ' + str(error))
    try:
        state = json_file(state_path)
        need(state.get('workflowSha') == args.workflow_sha, 'Workflow state mismatch')
        current = source_identity(source, m, state=state)
        print(json.dumps({'finalSourceIdentity': current}), flush=True)
        verify_outcomes(os.environ)
    except (GateError, ValueError, OSError, KeyError, TypeError) as error:
        errors.append(str(error))
    print(json.dumps({'scope': 'host fixture/build identity checks only; no native/backend/store/release acceptance',
                      'sourceCommit': SOURCE, 'overlayPatchSha256': m['overlayPatchSha256'],
              'sourceStackSha256': m['sourceStackSha256'],
              'composedTreeGitSha1': m['composedTreeGitSha1'],
                      'workflowCommit': args.workflow_sha, 'artifactsUploaded': False,
                      'errors': errors, 'success': not errors}), flush=True)
    need(not errors, 'Final evidence/source gate failed')
    return 0


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except (GateError, ValueError, OSError, KeyError, TypeError) as error:
        print('EVIDENCE GATE ERROR: ' + str(error), file=sys.stderr)
        raise SystemExit(1)
