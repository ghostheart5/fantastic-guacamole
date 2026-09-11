import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import Mock
import zipfile

import native_instrumentation as native


def report(count=6):
    rows = []
    for index in range(count):
        for code in (1, 0):
            rows.extend([f'INSTRUMENTATION_STATUS: class={native.TEST_CLASS}',
                         f'INSTRUMENTATION_STATUS: test=real Dart test {index}',
                         'INSTRUMENTATION_STATUS: numtests=1',
                         f'INSTRUMENTATION_STATUS_CODE: {code}'])
    return '\n'.join(rows + ['INSTRUMENTATION_RESULT: stream=', f'OK ({count} tests)',
                             'INSTRUMENTATION_CODE: -1']) + '\n'


def preparation(filename):
    return {'schema': native.SCHEMA, 'file': filename, 'targetSha256': 'd' * 64,
            'apks': {name: {'sha256': 'e' * 64, 'bytes': 100} for name in ('app.apk', 'test.apk')}}


def write_evidence(directory, label, filename, count):
    directory.mkdir(parents=True, exist_ok=True)
    raw = directory / (label + '.log')
    raw.write_text(report(count), encoding='utf-8')
    receipt = {'schema': native.SCHEMA, 'passed': True, 'runnerExitCode': 0,
               **native.parse_report(report(count), count), 'rawReportSha256': native.sha256(raw),
               'prepared': preparation(filename)}
    path = directory / (label + '-instrumentation.json')
    path.write_text(json.dumps(receipt), encoding='utf-8')
    return receipt


class InstrumentationTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)

    def test_counts_actual_dart_results_despite_one_discovered_container(self):
        result = native.parse_report(report(), 6)
        self.assertEqual(result['totals'], {'total': 6, 'passed': 6, 'failed': 0, 'error': 0, 'skipped': 0})
        self.assertEqual(len(result['completedTestNames']), 6)

    def test_rejects_failure_error_ignored_assumption_and_unknown_status(self):
        for status in ('-1', '-2', '-3', '-4', '2', 'garbage'):
            with self.subTest(status=status), self.assertRaises(RuntimeError):
                native.parse_report(report().replace('STATUS_CODE: 0', 'STATUS_CODE: ' + status, 1), 6)

    def test_rejects_truncation_duplicate_omitted_extra_or_wrong_tests(self):
        original = report()
        invalid = [original.replace('INSTRUMENTATION_CODE: -1', ''),
                   original + 'INSTRUMENTATION_CODE: -1\n',
                   original.replace('INSTRUMENTATION_CODE: -1', 'INSTRUMENTATION_CODE: 0'),
                   original.replace('real Dart test 1', 'real Dart test 0'),
                   original.replace(native.TEST_CLASS, 'another.Test', 1),
                   original.replace('STATUS_CODE: 1', 'STATUS_CODE: 0', 1),
                   original.replace('OK (6 tests)', 'OK (1 test)'),
                   original.replace('INSTRUMENTATION_STATUS: test=real Dart test 0\n', '', 1),
                   report(5), report(7), '', original + 'INSTRUMENTATION_FAILED: Process crashed\n',
                   original + 'INSTRUMENTATION_STATUS_CODE: 0\n']
        for index, raw in enumerate(invalid):
            with self.subTest(index=index), self.assertRaises(RuntimeError):
                native.parse_report(raw, 6)

    def test_reparses_raw_output_and_binds_preparation_instead_of_trusting_green_json(self):
        label, filename = 'auth-320x640', 'auth_flow_integration_test.dart'
        receipt = write_evidence(self.root, label, filename, 6)
        self.assertEqual(native.verify_evidence(self.root, label, filename, 6)['totals']['passed'], 6)
        path = self.root / (label + '-instrumentation.json')
        changes = [{'passed': False}, {'runnerExitCode': 1}, {'rawReportSha256': 'f' * 64},
                   {'completedTestNames': ['invented']}, {'prepared': {}}]
        for change in changes:
            path.write_text(json.dumps({**receipt, **change}))
            with self.subTest(change=change), self.assertRaises(RuntimeError):
                native.verify_evidence(self.root, label, filename, 6)
        path.write_text(json.dumps(receipt))
        (self.root / (label + '.log')).write_text(report(5))
        with self.assertRaises(RuntimeError):
            native.verify_evidence(self.root, label, filename, 6)

    def test_builds_assigned_target_and_external_harness_without_starting_guest(self):
        source = self.root / 'source'
        target = source / 'integration_test/planner_learning_identity_test.dart'
        target.parent.mkdir(parents=True)
        target.write_text('unchanged fixture')
        tooling = Path(__file__).resolve().parents[1]
        calls = []
        def build(label, argv, **kwargs):
            calls.append((label, argv))
            if label == 'compile-native-dependencies':
                self.assertIn('integration_test/' + target.name, argv)
            else:
                self.assertIn('-Ptarget=' + str(target.resolve()), argv)
                self.assertIn('--init-script', argv)
                for relative in ('debug/app-debug.apk', 'androidTest/debug/app-debug-androidTest.apk'):
                    path = source / 'build/app/outputs/apk' / relative
                    path.parent.mkdir(parents=True)
                    with zipfile.ZipFile(path, 'w') as bundle:
                        bundle.writestr('fixture', relative)
        commands = Mock()
        commands.run.side_effect = build
        receipt = native.prepare(commands, source, tooling, target.name)
        self.assertEqual(receipt['targetSha256'], native.sha256(target))
        self.assertEqual(len(calls), 2)
        self.assertEqual(target.read_text(), 'unchanged fixture')
        self.assertFalse((source / 'android/app/src/androidTest').exists())
        with self.assertRaisesRegex(RuntimeError, 'must be fresh'):
            native.prepare(commands, source, tooling, target.name)

    def test_missing_apks_and_failed_build_cannot_prepare(self):
        for index, side_effect in enumerate((None, RuntimeError('failed compilation'))):
            source = self.root / str(index)
            target = source / 'integration_test/app_startup_test.dart'
            target.parent.mkdir(parents=True)
            target.write_text('fixture')
            commands = Mock()
            commands.run.side_effect = side_effect
            with self.assertRaises(RuntimeError):
                native.prepare(commands, source, Path(__file__).resolve().parents[1], target.name)
            self.assertFalse((source / 'build/chronospark-native-fixture/prepared.json').exists())

    def test_install_rejects_personal_device_before_any_command(self):
        commands = Mock()
        with self.assertRaisesRegex(RuntimeError, 'owned emulator'):
            native.execute(commands, self.root, ['adb', '-s', 'ZY22G665VG'], 'app_startup_test.dart', 1, 'startup')
        commands.run.assert_not_called()

    def test_execute_binds_apks_and_rejects_failed_command_even_with_green_output(self):
        source = self.root / 'source'
        filename, label = 'app_startup_test.dart', 'startup-320x640'
        target = source / 'integration_test' / filename
        target.parent.mkdir(parents=True)
        target.write_text('fixture')
        directory = source / 'build/chronospark-native-fixture'
        directory.mkdir(parents=True)
        prepared = preparation(filename)
        prepared['targetSha256'] = native.sha256(target)
        for name in ('app.apk', 'test.apk'):
            (directory / name).write_bytes(name.encode())
            prepared['apks'][name] = {'sha256': native.sha256(directory / name), 'bytes': len(name)}
        (directory / 'prepared.json').write_text(json.dumps(prepared))
        for code in (0, 1):
            evidence = self.root / f'evidence-{code}'
            evidence.mkdir()
            commands = Mock(evidence=evidence, records=[])
            def run(command_label, argv, **kwargs):
                commands.records.append({'label': command_label, 'exitCode': code})
                if command_label == label:
                    self.assertEqual(argv[-1], native.COMPONENT)
                    self.assertIn('instrument', argv)
                    (evidence / (label + '.log')).write_text(report(1))
                    return report(1)
                return 'Success'
            commands.run.side_effect = run
            if code:
                with self.assertRaisesRegex(RuntimeError, 'did not complete'):
                    native.execute(commands, source, ['adb', '-s', 'emulator-5592'], filename, 1, label)
                self.assertFalse((evidence / (label + '-instrumentation.json')).exists())
            else:
                native.execute(commands, source, ['adb', '-s', 'emulator-5592'], filename, 1, label)
                self.assertEqual(native.verify_evidence(evidence, label, filename, 1)['totals']['passed'], 1)
        (directory / 'app.apk').write_bytes(b'changed')
        commands.run.reset_mock()
        with self.assertRaisesRegex(RuntimeError, 'APK bytes changed'):
            native.execute(commands, source, ['adb', '-s', 'emulator-5592'], filename, 1, label)
        commands.run.assert_not_called()


if __name__ == '__main__':
    unittest.main()
