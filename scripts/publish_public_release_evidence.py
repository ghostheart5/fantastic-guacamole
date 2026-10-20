"""Validate an operator packet before making it available to the release builder."""
import argparse
import os
from pathlib import Path
import re
import subprocess
import tempfile

from public_release_profile import (
    PUBLIC_POLICY, PUBLIC_SETTINGS, assemble_public_defines, canonical,
    require, resolve_public_settings, strict_json, validate_public_evidence, validate_source_gates,
)


def publish(packet_text, output, source_sha, defines, source, now=None):
    require(len(packet_text.encode('utf-8')) <= 60000, 'Evidence packet is too large')
    packet = strict_json(packet_text)
    require(type(packet) is dict and set(packet) == {'receipt', 'records'},
            'Expected receipt and records only')
    records = packet['records']
    require(type(records) is dict and len(records) == 6,
            'Expected six reviewed record files')
    for name, content in records.items():
        require(type(name) is str and re.fullmatch(r'[A-Za-z0-9_-]+\.(md|txt|json)', name)
                and name != 'public-release-evidence.json' and type(content) is str,
                'Record names must be simple relative files with text contents')
    receipt = packet['receipt']
    require(type(receipt) is dict and type(receipt.get('gates')) is dict,
            'Missing gate receipt')
    require({gate.get('file') for gate in receipt['gates'].values()
             if type(gate) is dict} == set(records), 'Missing or unrelated record files')
    validate_source_gates(source)
    output = Path(output)
    require(not output.exists(), 'Evidence output already exists')
    # Validate in an isolated folder first. Failed packets leave no upload folder.
    with tempfile.TemporaryDirectory() as temporary:
        root = Path(temporary)
        for name, content in records.items():
            (root / name).write_bytes(content.encode('utf-8'))
        verdict = validate_public_evidence(receipt, root, source_sha, defines, now)
        output.mkdir(parents=True)
        for name, content in records.items():
            (output / name).write_bytes(content.encode('utf-8'))
        (output / 'public-release-evidence.json').write_bytes(canonical(receipt).encode('utf-8'))
    return verdict


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', required=True)
    args = parser.parse_args()
    sha = subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip()
    settings = resolve_public_settings({key: os.environ.get(key) for key in PUBLIC_SETTINGS})
    defines = assemble_public_defines(settings, PUBLIC_POLICY)
    verdict = publish(os.environ['PUBLIC_EVIDENCE_PACKET'], args.output, sha,
                      defines, Path('lib/config/launch_containment.dart').read_text(encoding='utf-8'))
    print(canonical(verdict))
