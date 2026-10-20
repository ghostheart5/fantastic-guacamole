"""Omit the pinned runner's unsolicited MENU event before HOME readiness.

Only startup input ordering changes. The unchanged HOME and ANR guards still
decide whether app tests may run; no error is dismissed, suppressed or retried.
"""
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess

UPSTREAM = 'a421e43855164a8197daf9d8d40fe71c6996bb0d'
ACTION_SHA256 = 'a7c4de9a466ae7d70a599ffdc5a27b2bccadd7b2d602e24b44f8b490cb7bbdfe'
ORIGINAL_SHA256 = 'a63db8fe9ffb4fb3651e9a2c97f8bac5ca4ce0078a7bbe61ef2e02019082c577'
PATCHED_SHA256 = '94372881064163092befd9d8b8d07577f401314a46d5aeff00014ce6a733da97'
MENU = b'        await adb(port, `shell input keyevent 82`);\n'
PASSIVE = b'        console.log("Passive startup: no MENU key injected before HOME readiness.");\n'


def digest(value):
    return hashlib.sha256(value).hexdigest()


def patch_module(original):
    if digest(original) != ORIGINAL_SHA256 or original.count(MENU) != 1:
        raise ValueError('Unexpected upstream emulator manager; no patch applied')
    patched = original.replace(MENU, PASSIVE, 1)
    if digest(patched) != PATCHED_SHA256:
        raise ValueError('Unexpected passive-startup patch output')
    return patched


def prepare(workspace):
    if (os.name != 'posix' or os.environ.get('GITHUB_ACTIONS') != 'true' or
            os.environ.get('RUNNER_ENVIRONMENT') != 'github-hosted'):
        raise ValueError('Only the disposable GitHub-hosted Linux runner is allowed')
    source = os.environ['QA_SOURCE_SHA']
    if not re.fullmatch('[0-9a-f]{40}', source):
        raise ValueError('Immutable application source is required')
    workspace = Path(workspace).resolve()
    runner = workspace / 'test-results/hosted-emulator-runner'
    receipt_root = workspace / 'test-results/maestro-prewarm'
    if runner.is_symlink() or receipt_root.is_symlink():
        raise ValueError('Runner and receipt roots must not be symlinks')
    if runner.resolve() != runner or receipt_root.resolve() != receipt_root:
        raise ValueError('Runner and receipts must stay in the owned evidence root')

    def git(path, *args):
        return subprocess.check_output(['git', '-C', str(path), *args], text=True).strip()

    if git(workspace, 'rev-parse', 'HEAD') != source:
        raise ValueError('Application source drifted')
    if git(runner, 'rev-parse', 'HEAD') != UPSTREAM or git(runner, 'status', '--porcelain'):
        raise ValueError('Upstream runner is not the clean pinned revision')
    action = runner / 'action.yml'
    module = runner / 'lib/emulator-manager.js'
    if action.is_symlink() or module.is_symlink():
        raise ValueError('Runner entry files must not be symlinks')
    if digest(action.read_bytes()) != ACTION_SHA256:
        raise ValueError('Upstream action metadata changed')
    original = module.read_bytes()
    patched = patch_module(original)
    receipt = {'sourceSha': source, 'workflowToolingSha': os.environ['GITHUB_SHA'],
               'runId': os.environ['GITHUB_RUN_ID'], 'runAttempt': os.environ['GITHUB_RUN_ATTEMPT'],
               'upstreamRepository': 'ReactiveCircus/android-emulator-runner',
               'upstreamCommit': UPSTREAM, 'upstreamActionSha256': ACTION_SHA256,
               'originalModuleSha256': digest(original), 'patchedModuleSha256': digest(patched),
               'patchToolSha256': digest(Path(__file__).read_bytes()),
               'unconditionalMenuInjectionRemoved': True, 'replacementCount': 1,
               'boundary': 'No startup key injection; unchanged HOME and ANR guards must still pass. '
                           'No dialog dismissal, error suppression, retry or application acceptance.'}
    with (receipt_root / 'upstream-emulator-manager.original.js').open('xb') as stream:
        stream.write(original)
    with (receipt_root / 'upstream-emulator-manager.passive.js').open('xb') as stream:
        stream.write(patched)
    with (receipt_root / 'runner-input-order.json').open('x') as stream:
        json.dump(receipt, stream, indent=2)
    module.write_bytes(patched)
    if module.read_bytes() != patched:
        raise ValueError('Patched runner readback mismatch')


if __name__ == '__main__':
    prepare(os.environ['GITHUB_WORKSPACE'])
