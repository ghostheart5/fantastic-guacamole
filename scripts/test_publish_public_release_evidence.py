import copy
import json
from pathlib import Path
import unittest

import test_public_release_profile as fixtures
from public_release_profile import SOURCE_CAPABILITIES
from publish_public_release_evidence import publish


class EvidencePublisherTests(unittest.TestCase):
    def setUp(self):
        fixture = fixtures.PublicProfileTests()
        fixture.setUp()
        self.addCleanup(fixture.doCleanups)
        self.fixture = fixture
        receipt = copy.deepcopy(fixture.evidence)
        content = (fixture.root / 'review.txt').read_text()
        records = {}
        for name, gate in receipt['gates'].items():
            gate['file'] = name + '.txt'
            records[gate['file']] = content
        self.packet = {'receipt': receipt, 'records': records}
        self.source = '\n'.join(f'static const bool {name} = true;' for name in SOURCE_CAPABILITIES)
        self.source += '\n' + '\n'.join(f'static const bool {name} = false;' for name in
                                       ('analyticsEnabled', 'crashReportingEnabled', 'inferredIdentityEnabled'))
        self.output = fixture.root / 'output'

    def run_packet(self, packet=None, source=None):
        f = self.fixture
        return publish(json.dumps(packet or self.packet), self.output, f.source_sha,
                       f.defines, source or self.source, f.now)

    def test_validated_artifact_can_be_consumed_by_release_builder(self):
        result = self.run_packet()
        self.assertEqual(result['sourceSha'], self.fixture.source_sha)
        receipt = json.loads((self.output / 'public-release-evidence.json').read_text())
        verdict = fixtures.validate_public_evidence(receipt, self.output,
            self.fixture.source_sha, self.fixture.defines, self.fixture.now)
        self.assertEqual(verdict, result)

    def test_paths_extra_files_duplicate_keys_and_oversize_fail_before_upload(self):
        for name in ('../review.txt', '/review.txt', 'review.txt:stream', 'other.txt'):
            packet = copy.deepcopy(self.packet)
            packet['records'][name] = 'unreviewed'
            with self.subTest(name=name), self.assertRaises(ValueError):
                self.run_packet(packet)
            self.assertFalse(self.output.exists())
        for text in ('{"receipt":{},"receipt":{},"records":{}}', 'x' * 60001):
            with self.assertRaises(ValueError):
                publish(text, self.output, self.fixture.source_sha,
                        self.fixture.defines, self.source, self.fixture.now)
            self.assertFalse(self.output.exists())

    def test_changed_record_source_configuration_or_disabled_capability_blocks_upload(self):
        packet = copy.deepcopy(self.packet)
        packet['records']['privacyDisclosureValidation.txt'] += 'changed after review'
        with self.assertRaises(ValueError):
            self.run_packet(packet)
        for field, wrong in (('sourceSha', 'b' * 40), ('definesSha256', '0' * 64)):
            packet = copy.deepcopy(self.packet)
            packet['receipt'][field] = wrong
            with self.subTest(field=field), self.assertRaises(ValueError):
                self.run_packet(packet)
        with self.assertRaises(ValueError):
            self.run_packet(source=self.source.replace('cloudSyncEnabled = true', 'cloudSyncEnabled = false'))
        self.assertFalse(self.output.exists())


if __name__ == '__main__':
    unittest.main()
