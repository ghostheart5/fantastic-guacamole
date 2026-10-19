import copy
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch
from prepare_qa_monkey_config import BASE, QA, SEEDS, JOURNEY_FLOWS, derive, package_from_badging, prepare, sha, verify


class QaMonkeyConfigTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='qa-monkey-config-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.target = self.root / 'test-results/monkey-qa-config'
        self.git('init', '--quiet')
        (self.root / '.gitignore').write_text('test-results/\nartifacts/\n')
        self.config = {'monkey': {'package': BASE, 'variants': [{'name': 'smoke', 'events': 100}, {'name': 'balanced', 'events': 500}, {'name': 'navigation', 'events': 300}, {'name': 'touch-motion', 'events': 500}, {'name': 'lifecycle', 'events': 300}]}, 'unchanged': {'timeout': 900}}
        (self.root / 'test-orchestrator.json').write_text(json.dumps(self.config))
        self.git('add', '.')
        self.git('-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.invalid', 'commit', '--quiet', '-m', 'fixture')
        self.source = self.git('rev-parse', 'HEAD').strip()
        self.apk = self.root / 'test-results/app.apk'
        self.apk.parent.mkdir()
        self.apk.write_bytes(b'fixture-not-real-apk')
        self.aapt = self.root / 'test-results/aapt'
        self.aapt.write_bytes(b'fixture-not-real-aapt')
        self.completion = self.root / 'test-results/maestro-prewarm/completion.json'
        self.write(self.completion, {'sourceSha': self.source, 'precompiledApkSha256': sha(self.apk), 'buildExitCode': 0, 'gradleStopExitCode': 0})
        self.seed_paths = []
        for index, flow in enumerate(sorted(SEEDS)):
            path = self.root / f'test-results/monkey-seed-ci/{index}/manifest.json'
            self.write(path, self.seed([flow]))
            self.seed_paths.append(path)

    def git(self, *args):
        return subprocess.check_output(['git', '-C', str(self.root), *args], text=True)

    def write(self, path, value):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(value))

    def seed(self, flows):
        return {'status': 'passed', 'suite': 'custom', 'buildProfile': 'qa', 'git': {'commit': self.source, 'dirty': False}, 'apk': {'sha256': sha(self.apk), 'externalHashVerified': True}, 'installedPackage': {'name': QA}, 'junit': {'testCases': len(flows), 'failures': 0, 'errors': 0, 'skipped': 0}, 'fatalMarkerCount': 0, 'logcatCapture': {'aliveThroughRun': True}, 'flows': flows}

    def invoke(self, seed_only=True, package=QA):
        result = subprocess.CompletedProcess([], 0, stdout=("package: name='" + package + "' versionCode='1'\n").encode(), stderr=b'')
        real_run = subprocess.run
        native_calls = []
        def run(command, **kwargs):
            if command[0] == str(self.aapt):
                native_calls.append(command)
                return result
            return real_run(command, **kwargs)
        with patch('prepare_qa_monkey_config.subprocess.run', side_effect=run):
            receipt = prepare(self.root, self.source, self.target, self.apk, self.aapt, seed_only)
            self.assertEqual(len(native_calls), 1)
        return receipt

    def mutate_seed(self, key, value):
        data = json.loads(self.seed_paths[0].read_text())
        cursor = data
        for component in key[:-1]:
            cursor = cursor[component]
        cursor[key[-1]] = value
        self.write(self.seed_paths[0], data)

    def test_only_package_changes_and_five_variants_1700_preserved(self):
        receipt = self.invoke()
        result = json.loads((self.target / 'config.json').read_text())
        result['monkey']['package'] = BASE
        self.assertEqual(result, self.config)
        self.assertEqual(len(result['monkey']['variants']), 5)
        self.assertEqual(sum(v['events'] for v in result['monkey']['variants']), 1700)
        self.assertEqual(receipt['package'], QA)
        self.assertEqual(verify(self.root, self.source, self.target, self.apk, True), receipt)

    def test_reject_wrong_source_and_dirty_source(self):
        with self.assertRaises(ValueError):
            prepare(self.root, '0' * 40, self.target, self.apk, self.aapt, True)
        (self.root / 'foreign.txt').write_text('dirty')
        with self.assertRaises(ValueError):
            self.invoke()
        self.assertFalse(self.target.exists())

    def test_base_or_foreign_apk_package_rejected(self):
        for package in (BASE, 'foreign.app'):
            with self.subTest(package=package), self.assertRaises(ValueError):
                self.invoke(package=package)
        self.assertFalse(self.target.exists())

    def test_missing_or_duplicate_manifest_package_rejected(self):
        for text in ('nothing', "package: name='" + QA + "' \npackage: name='" + QA + "' \n"):
            with self.assertRaises(ValueError):
                package_from_badging(text)

    def test_missing_or_wrong_seed_package_hash_source_and_runtime_rejected(self):
        original = self.seed_paths[0].read_text()
        for key, value in [(('installedPackage', 'name'), BASE), (('apk', 'sha256'), '0' * 64), (('git', 'commit'), '0' * 40), (('git', 'dirty'), True), (('status',), 'failed'), (('junit', 'skipped'), 1), (('fatalMarkerCount',), 1), (('logcatCapture', 'aliveThroughRun'), False)]:
            with self.subTest(key=key):
                self.seed_paths[0].write_text(original)
                self.mutate_seed(key, value)
                with self.assertRaises(ValueError):
                    self.invoke()
                self.assertFalse(self.target.exists())

    def test_precompile_hash_or_source_mismatch_rejected(self):
        original = json.loads(self.completion.read_text())
        for key, value in [('precompiledApkSha256', '0' * 64), ('sourceSha', '0' * 40), ('buildExitCode', 1)]:
            self.write(self.completion, {**original, key: value})
            with self.assertRaises(ValueError):
                self.invoke()

    def test_wrong_source_config_package_no_fallback(self):
        for package in (QA, 'foreign.app', ''):
            config = copy.deepcopy(self.config)
            config['monkey']['package'] = package
            with self.assertRaises(ValueError):
                derive(config, QA)

    def test_seed_flow_identity_duplicate_and_count_rejected(self):
        self.mutate_seed(('flows',), [sorted(SEEDS)[1]])
        with self.assertRaises(ValueError):
            self.invoke()
        self.seed_paths[1].unlink()
        with self.assertRaises(ValueError):
            self.invoke()

    def test_changed_derived_variant_or_package_or_provenance_rejected(self):
        self.invoke()
        path = self.target / 'config.json'
        original = path.read_text()
        for field in ('events', 'package'):
            result = json.loads(original)
            if field == 'events':
                result['monkey']['variants'][0]['events'] = 999
            else:
                result['monkey']['package'] = BASE
            self.write(path, result)
            with self.assertRaises(ValueError):
                verify(self.root, self.source, self.target, self.apk, True)
        path.write_text(original)
        receipt = self.target / 'provenance.json'
        result = json.loads(receipt.read_text())
        result['sourceSha'] = '0' * 40
        self.write(receipt, result)
        with self.assertRaises(ValueError):
            verify(self.root, self.source, self.target, self.apk, True)

    def test_no_overwrite_or_outside_output(self):
        self.invoke()
        with self.assertRaises(ValueError):
            self.invoke()
        for target in (self.root, self.root / 'test-results', self.root.parent / 'outside'):
            with self.assertRaises(ValueError):
                prepare(self.root, self.source, target, self.apk, self.aapt, True)

    def test_combined_requires_exact_ordered_full_journey_receipt(self):
        path = self.root / 'artifacts/maestro-ci/combined/manifest.json'
        combined = self.seed(JOURNEY_FLOWS)
        combined['suite'] = 'qa-journeys'
        self.write(path, combined)
        self.invoke(seed_only=False)
        self.assertEqual(verify(self.root, self.source, self.target, self.apk, False)['seedOnly'], False)
        combined['flows'] = list(reversed(JOURNEY_FLOWS))
        self.write(path, combined)
        with self.assertRaises(ValueError):
            verify(self.root, self.source, self.target, self.apk, False)


class WorkflowConfigContractTests(unittest.TestCase):
    def test_derived_config_is_used_reverified_and_uploaded(self):
        text = (Path(__file__).resolve().parents[1] / '.github/workflows/maestro-runtime.yml').read_text()
        self.assertIn('-Config "$GITHUB_WORKSPACE/test-results/monkey-qa-config/config.json"', text)
        self.assertNotIn('-Config "$GITHUB_WORKSPACE/test-orchestrator.json"', text)
        self.assertIn("assert m['package'] == 'com.ghostheart5.chronospark.qa'", text)
        self.assertIn("'--verify', '--root'", text)
        upload = text.split('- name: Upload complete Maestro evidence', 1)[1]
        self.assertIn('test-results/monkey-qa-config/**', upload)


if __name__ == '__main__':
    unittest.main()
