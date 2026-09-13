"""Copy immutable Maestro seeds, retaining or upgrading verified text entry."""
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys

FLOW = '.maestro/flows/priority8-learned-lifecycle.yaml'
LEGACY = '- inputText: "Priority 8 journey seed"\n'
VERIFIED = ('- runFlow:\n'
            '    file: ../subflows/enter-planner-request.yaml\n'
            '    env:\n'
            '      REQUEST: "Priority 8 journey seed"\n')


def snapshot(root, source):
    if not re.fullmatch(r'[a-f0-9]{40}', source):
        raise ValueError('An immutable source SHA is required')
    def git(*args):
        return subprocess.check_output(['git', '-C', str(root), *args])
    if git('rev-parse', 'HEAD').decode().strip() != source:
        raise ValueError('Source checkout identity changed')
    names = git('ls-tree', '-r', '--name-only', source, '--', '.maestro').decode().splitlines()
    if FLOW not in names:
        raise ValueError('Learned lifecycle flow is missing')
    payloads = {}
    rows = []
    transformation = 'none'
    for name in names:
        relative = Path(name)
        if relative.parts[0] != '.maestro' or '..' in relative.parts:
            raise ValueError('Invalid source path')
        original = git('show', source + ':' + name)
        output = original
        if name == FLOW:
            text = original.decode('utf-8')
            if text.count(VERIFIED) == 1 and text.count(LEGACY) == 0:
                pass  # Current source already uses verified entry; preserve bytes.
            elif text.count(LEGACY) == 1 and text.count(VERIFIED) == 0:
                output = text.replace(LEGACY, VERIFIED).encode('utf-8')
                transformation = 'creator-input-helper'
            else:
                raise ValueError('Unrecognized or ambiguous Creator seed entry')
        payloads[name] = output
        rows.append(dict(path=name, sourceSha256=hashlib.sha256(original).hexdigest(),
                         executedSha256=hashlib.sha256(output).hexdigest()))
    if '.maestro/subflows/enter-planner-request.yaml' not in payloads:
        raise ValueError('Verified text-entry subflow is missing')
    return payloads, dict(sourceSha=source, transformation=transformation, files=rows)


def target_path(root, target):
    target = Path(target).resolve()
    evidence = root / 'test-results'
    if target == evidence or not target.is_relative_to(evidence):
        raise ValueError('Seeds must stay within the source evidence directory')
    return target


def prepare(root, source, target):
    root = Path(root).resolve()
    target = target_path(root, target)
    if target.exists():
        raise FileExistsError('Never overwrite an existing evidence directory')
    # Validate every blob and the seed shape before writing any output.
    payloads, receipt = snapshot(root, source)
    for name, data in payloads.items():
        destination = target / name
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(data)
    (target / 'provenance.json').write_text(json.dumps(receipt, indent=2) + '\n', encoding='utf-8')
    return receipt


def verify(root, source, target):
    root = Path(root).resolve()
    target = target_path(root, target)
    payloads, expected = snapshot(root, source)
    receipt = json.loads((target / 'provenance.json').read_text(encoding='utf-8'))
    if receipt != expected:
        raise ValueError('Seed provenance does not match the immutable source')
    actual_names = {p.relative_to(target).as_posix() for p in target.rglob('*') if p.is_file()}
    if actual_names != set(payloads) | {'provenance.json'}:
        raise ValueError('Seed file set differs from the immutable source')
    for name, data in payloads.items():
        if (target / name).read_bytes() != data:
            raise ValueError('Executed seed content changed: ' + name)
    return receipt


if __name__ == '__main__':
    if sys.argv[1:2] == ['--verify']:
        verify(*sys.argv[2:])
    else:
        prepare(*sys.argv[1:])
