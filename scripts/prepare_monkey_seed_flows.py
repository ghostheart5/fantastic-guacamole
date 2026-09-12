"""Prepare source-bound seed flows with verified Creator text entry."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys


def prepare(root, source, target):
    root = Path(root).resolve()
    target = Path(target).resolve()
    assert target.is_relative_to(root / 'test-results')
    assert not target.exists(), 'Never overwrite an existing evidence directory'
    assert subprocess.check_output(['git', '-C', str(root), 'rev-parse', 'HEAD'], text=True).strip() == source
    files = subprocess.check_output(['git', '-C', str(root), 'ls-tree', '-r', '--name-only', source, '--', '.maestro'], text=True).splitlines()
    assert files
    changed = '.maestro/flows/priority8-learned-lifecycle.yaml'
    needle = '- inputText: "Priority 8 journey seed"\n'
    replacement = ('- runFlow:\n'
                   '    file: ../subflows/enter-planner-request.yaml\n'
                   '    env:\n'
                   '      REQUEST: "Priority 8 journey seed"\n')
    receipt = {'sourceSha': source, 'changedFlow': changed, 'files': []}
    for name in files:
        relative = Path(name)
        assert relative.parts[0] == '.maestro' and '..' not in relative.parts
        original = subprocess.check_output(['git', '-C', str(root), 'show', source + ':' + name])
        output = original
        if name == changed:
            text = original.decode('utf-8')
            assert text.count(needle) == 1
            output = text.replace(needle, replacement).encode('utf-8')
        destination = target / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(output)
        receipt['files'].append({'path': name, 'sourceSha256': hashlib.sha256(original).hexdigest(), 'executedSha256': hashlib.sha256(output).hexdigest()})
    changed_rows = [r for r in receipt['files'] if r['sourceSha256'] != r['executedSha256']]
    assert len(changed_rows) == 1 and changed_rows[0]['path'] == changed
    (target / 'provenance.json').write_text(json.dumps(receipt, indent=2) + '\n', encoding='utf-8')
    return receipt


if __name__ == '__main__':
    prepare(*sys.argv[1:])
