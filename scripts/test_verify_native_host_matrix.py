import copy
from pathlib import Path
import tempfile
import unittest

from android_final_validation import read_json, write_json
from verify_native_host_matrix import verify


class NativeHostMatrixTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.expected = {'sourceSha': 'a' * 40, 'candidateSourceSha': 'a' * 40,
                         'validationSourceSha': 'a' * 40, 'validationToolingSha': 'b' * 40,
                         'validationRunId': '123', 'validationRunAttempt': '1',
                         'repository': 'owner/repo', 'candidateRunId': '122',
                         'aabSha256': 'c' * 64, 'jobsResult': 'success'}
        cases = [('app_startup_test', '320x640', 1), ('auth_flow_integration_test', '320x640', 6),
                 ('persistence_recovery_test', '320x640', 1), ('planner_learning_identity_test', '320x640', 1),
                 ('auth_flow_integration_test', '411x891', 6)]
        for index, (stem, viewport, count) in enumerate(cases, 1):
            artifact = self.root / str(index)
            write_json(artifact / 'source-provenance.json', {
                **self.expected, 'nativeCase': str(index),
                'hostBootId': f'00000000-0000-0000-0000-{index:012d}',
                'commandsExecutedAfterCompletedCandidateGate': True})
            totals = {'total': count, 'passed': count, 'failed': 0, 'error': 0, 'skipped': 0}
            label = f'{index:02d}-{stem}-{viewport}'
            run = {'file': stem + '.dart', 'viewport': viewport, 'expectedTests': count,
                   'passed': True, 'ownedEmulatorStopped': True, 'ownedLogCollectorStopped': True,
                   'ownedAdbServerStopped': True, 'ownedAdbServerContinuous': True,
                   'totals': totals, 'failures': [], 'runnerExitCode': 0,
                   'runtimeEvidence': {'fatalLines': []}, 'evidenceDirectory': label}
            write_json(artifact / 'native/android-result.json', {
                'passed': True, 'expectedInvocations': 1, 'completedInvocations': 1,
                'expectedTests': count, 'caseOrdinals': [index], 'notRun': [], 'runs': [run]})
            directory = artifact / 'native' / label
            write_json(directory / f'{stem}-{viewport}-manifest.json', {
                'finalSuccess': True, 'exitCode': 0, 'terminalCompletion': True, 'terminalSuccess': True,
                'timedOut': False, 'launchFailed': False, 'totals': totals,
                'completedTests': count, 'reportParseErrors': []})
            (directory / f'{stem}-{viewport}.jsonl').write_text('{"type":"done","success":true}\n')

    def test_requires_all_five_hosts_and_exact_fifteen_zero_skip_tests(self):
        result = verify(self.root, self.expected)
        self.assertEqual(result['totals'], {'total': 15, 'passed': 15, 'failed': 0, 'error': 0, 'skipped': 0})
        self.assertEqual(len(result['runs']), 5)
        with self.assertRaisesRegex(RuntimeError, 'Exactly five'):
            verify(self.root / '1', self.expected)
        with self.assertRaisesRegex(RuntimeError, 'job failed'):
            verify(self.root, {**self.expected, 'jobsResult': 'failure'})

    def test_rejects_wrong_source_attempt_duplicate_case_and_reused_host(self):
        path = self.root / '2/source-provenance.json'
        original = read_json(path)
        changes = [{'sourceSha': 'd' * 40}, {'validationRunAttempt': '2'}, {'validationRunId': '124'},
                   {'validationToolingSha': 'e' * 40}, {'nativeCase': '1'},
                   {'hostBootId': '00000000-0000-0000-0000-000000000001'}]
        for change in changes:
            write_json(path, {**original, **change})
            with self.subTest(change=change), self.assertRaises(RuntimeError):
                verify(self.root, self.expected)
        write_json(path, original)

    def test_rejects_partial_skipped_failed_and_disconnected_invocations(self):
        path = self.root / '2/native/android-result.json'
        original = read_json(path)
        for field, value in [('ownedAdbServerContinuous', False), ('ownedEmulatorStopped', False),
                             ('ownedLogCollectorStopped', False), ('runnerExitCode', 1),
                             ('viewport', '411x891'), ('failures', ['transport gap']),
                             ('totals', {'total': 6, 'passed': 5, 'failed': 0, 'error': 0, 'skipped': 1})]:
            changed = copy.deepcopy(original)
            changed['runs'][0][field] = value
            write_json(path, changed)
            with self.subTest(field=field), self.assertRaises(RuntimeError):
                verify(self.root, self.expected)
        write_json(path, original)

    def test_rejects_green_summary_with_failed_canonical_manifest(self):
        path = next((self.root / '2').rglob('*-manifest.json'))
        manifest = read_json(path)
        manifest['terminalCompletion'] = False
        write_json(path, manifest)
        with self.assertRaisesRegex(RuntimeError, 'Canonical test receipt'):
            verify(self.root, self.expected)


if __name__ == '__main__':
    unittest.main()
