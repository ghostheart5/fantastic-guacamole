import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from prepare_monkey_seed_flows import FLOW, LEGACY, VERIFIED, prepare, verify


class SeedPreparationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='chronospark-seed-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.target = self.root / 'test-results' / 'seed'
        self.git('init', '--quiet')

    def git(self, *args):
        return subprocess.check_output(['git', '-C', str(self.root), *args]).decode().strip()

    def commit(self, text):
        flow = self.root / FLOW
        flow.parent.mkdir(parents=True, exist_ok=True)
        flow.write_text('appId: example\n---\n' + text, encoding='utf-8', newline='\n')
        helper = self.root / '.maestro/subflows/enter-planner-request.yaml'
        helper.parent.mkdir(parents=True, exist_ok=True)
        helper.write_text('appId: example\n---\n- assertVisible: "${REQUEST}"\n', encoding='utf-8', newline='\n')
        self.git('add', '.maestro')
        self.git('-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.invalid', 'commit', '--quiet', '-m', 'fixture')
        return self.git('rev-parse', 'HEAD')

    def test_current_source_keeps_every_blob_unchanged(self):
        sha = self.commit(VERIFIED)
        receipt = prepare(self.root, sha, self.target)
        self.assertEqual(receipt['transformation'], 'none')
        self.assertTrue(all(r['sourceSha256'] == r['executedSha256'] for r in receipt['files']))
        self.assertEqual(verify(self.root, sha, self.target), receipt)

    def test_legacy_source_transforms_only_creator_entry(self):
        sha = self.commit(LEGACY)
        receipt = prepare(self.root, sha, self.target)
        self.assertEqual(receipt['transformation'], 'creator-input-helper')
        self.assertEqual([r['path'] for r in receipt['files'] if r['sourceSha256'] != r['executedSha256']], [FLOW])
        self.assertIn(VERIFIED, (self.target / FLOW).read_text())
        verify(self.root, sha, self.target)

    def test_unknown_or_ambiguous_shapes_fail_before_writing(self):
        for text in [LEGACY + VERIFIED, VERIFIED * 2, '- inputText: "unexpected"\n']:
            with self.subTest(text=text):
                sha = self.commit(text)
                with self.assertRaises(ValueError): prepare(self.root, sha, self.target)
                self.assertFalse(self.target.exists())

    def test_evidence_is_never_overwritten_or_written_outside_test_results(self):
        sha = self.commit(VERIFIED)
        for destination in [self.root / 'source', self.root / 'test-results']:
            with self.assertRaises(ValueError): prepare(self.root, sha, destination)
        prepare(self.root, sha, self.target)
        with self.assertRaises(FileExistsError): prepare(self.root, sha, self.target)
        verify(self.root, sha, self.target)

    def test_wrong_source_and_changed_execution_are_rejected(self):
        sha = self.commit(VERIFIED)
        with self.assertRaises(ValueError): prepare(self.root, '0' * 40, self.target)
        prepare(self.root, sha, self.target)
        (self.target / FLOW).write_text('tampered', encoding='utf-8')
        with self.assertRaises(ValueError): verify(self.root, sha, self.target)

    def test_forged_provenance_and_extra_files_are_rejected(self):
        sha = self.commit(VERIFIED)
        prepare(self.root, sha, self.target)
        provenance = self.target / 'provenance.json'
        original = provenance.read_text()
        forged = json.loads(original)
        forged['sourceSha'] = '0' * 40
        provenance.write_text(json.dumps(forged), encoding='utf-8')
        with self.assertRaises(ValueError): verify(self.root, sha, self.target)
        provenance.write_text(original, encoding='utf-8')
        (self.target / 'extra.yaml').write_text('extra', encoding='utf-8')
        with self.assertRaises(ValueError): verify(self.root, sha, self.target)


if __name__ == '__main__':
    unittest.main()
