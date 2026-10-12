"""Copy source flows for the isolated QA package without altering source files."""
import argparse
import hashlib
import json
import re
import shutil
from pathlib import Path

QA_PACKAGE = 'com.ghostheart5.chronospark.qa'


def prepare(flows, output):
    output = Path(output).resolve()
    roots = {}
    prepared = []
    receipts = []
    for flow in flows:
        flow = Path(flow).resolve(strict=True)
        root = next((p for p in flow.parents if p.name == '.maestro'), None)
        if root is None:
            raise ValueError('QA flows must be inside a .maestro source tree')
        if output == root or root in output.parents:
            raise ValueError('Output must be outside the source flow tree')
        if root not in roots:
            destination = output / str(len(roots)) / '.maestro'
            shutil.copytree(root, destination)
            roots[root] = destination
            for source in root.rglob('*.yaml'):
                relative = source.relative_to(root)
                target = destination / relative
                raw = source.read_bytes()
                text = raw.decode('utf-8-sig')
                rewritten, count = re.subn(
                    r'^appId: com\.ghostheart5\.chronospark[ \t]*\r?$',
                    'appId: ' + QA_PACKAGE,
                    text, flags=re.MULTILINE,
                )
                if count != 1:
                    raise ValueError(f'Expected one canonical appId: {relative}')
                target.write_bytes(rewritten.encode('utf-8'))
                receipts.append({'source': str(source), 'prepared': str(target),
                                 'sourceSha256': hashlib.sha256(raw).hexdigest(),
                                 'preparedSha256': hashlib.sha256(target.read_bytes()).hexdigest()})
        prepared.append(str(roots[root] / flow.relative_to(root)))
    receipt = {'package': QA_PACKAGE, 'flows': prepared, 'files': receipts,
               'boundary': 'Package header and UTF-8 header encoding normalized; source commands and dependencies are preserved.'}
    output.mkdir(parents=True, exist_ok=True)
    (output / 'flow-remapping.json').write_text(json.dumps(receipt, indent=2), encoding='utf-8')
    return prepared


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--flow', action='append', required=True)
    parser.add_argument('--output', required=True)
    args = parser.parse_args()
    print(json.dumps(prepare(args.flow, args.output)))
