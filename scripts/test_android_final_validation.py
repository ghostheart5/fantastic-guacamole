"""Adversarial provenance/terminal checks; no devices, SDK installs or builds."""
import hashlib
from contextlib import ExitStack, contextmanager
import json
import os
import stat
import struct
import subprocess
from pathlib import Path
from types import SimpleNamespace
import tempfile
import unittest
from unittest.mock import patch
import warnings
import zipfile
import zlib

import android_final_validation as gate


class FinalValidationTest(unittest.TestCase):
    def image_archive_fixture(self, names):
        archive = self.root / 'fixture-image.zip'
        with zipfile.ZipFile(archive, 'w') as bundle:
            for name in names:
                bundle.writestr(name, b'verified fixture image')
        return archive

    def test_verified_image_repair_restores_partial_image_only(self):
        names = ['x86_64/' + name for name in
                 ('source.properties', 'system.img', 'vendor.img', 'ramdisk.img', 'kernel-ranchu')]
        archive = self.image_archive_fixture(names)
        sdk = self.root / 'sdk'
        directory = sdk / 'system-images/android-36/google_apis/x86_64'
        directory.mkdir(parents=True)
        (directory / 'vendor.img').write_bytes(b'partial')
        unrelated = sdk / 'other-package'
        unrelated.write_bytes(b'preserve')
        commands = gate.Commands(self.root / 'evidence')
        def download(label, argv, **kwargs):
            Path(argv[-1]).write_bytes(archive.read_bytes())
        with patch.dict(os.environ, GITHUB_ACTIONS='true', RUNNER_ENVIRONMENT='github-hosted', RUNNER_TEMP=str(self.root)), \
                patch.object(gate, 'NATIVE_IMAGE_SHA1', hashlib.sha1(archive.read_bytes()).hexdigest()), \
                patch.object(gate, 'NATIVE_IMAGE_BYTES', archive.stat().st_size), \
                patch.object(commands, 'run', side_effect=download):
            result = gate.repair_partial_native_image(commands, sdk, 'system-images;android-36;google_apis;x86_64')
        self.assertEqual(len(result['files']), 5)
        self.assertEqual(unrelated.read_bytes(), b'preserve')
        self.assertTrue(all((directory / Path(name).name).read_bytes() == b'verified fixture image' for name in names))

    def test_verified_image_repair_rejects_checksum_before_extraction(self):
        archive = self.image_archive_fixture(['x86_64/source.properties'])
        commands = gate.Commands(self.root / 'evidence')
        with patch.dict(os.environ, GITHUB_ACTIONS='true', RUNNER_ENVIRONMENT='github-hosted', RUNNER_TEMP=str(self.root)), \
                patch.object(gate, 'NATIVE_IMAGE_BYTES', archive.stat().st_size), \
                patch.object(commands, 'run', side_effect=lambda label, argv, **kw: Path(argv[-1]).write_bytes(archive.read_bytes())):
            with self.assertRaisesRegex(RuntimeError, 'pinned official'):
                gate.repair_partial_native_image(commands, self.root / 'sdk', 'system-images;android-36;google_apis;x86_64')
        self.assertFalse((self.root / 'sdk').exists())

    def test_verified_image_repair_rejects_traversal_before_any_extraction(self):
        archive = self.image_archive_fixture(['x86_64/source.properties', 'x86_64/../../escape'])
        commands = gate.Commands(self.root / 'evidence')
        with patch.dict(os.environ, GITHUB_ACTIONS='true', RUNNER_ENVIRONMENT='github-hosted', RUNNER_TEMP=str(self.root)), \
                patch.object(gate, 'NATIVE_IMAGE_SHA1', hashlib.sha1(archive.read_bytes()).hexdigest()), \
                patch.object(gate, 'NATIVE_IMAGE_BYTES', archive.stat().st_size), \
                patch.object(commands, 'run', side_effect=lambda label, argv, **kw: Path(argv[-1]).write_bytes(archive.read_bytes())):
            with self.assertRaisesRegex(RuntimeError, 'Unsafe image'):
                gate.repair_partial_native_image(commands, self.root / 'sdk', 'system-images;android-36;google_apis;x86_64')
        self.assertFalse((self.root / 'sdk').exists())

    def test_sdk_setup_requires_complete_files_and_explicit_root(self):
        sdk = self.root / 'sdk'
        image_id = 'system-images;android-36;google_apis;x86_64'
        directory = sdk / Path(*image_id.split(';'))
        commands = gate.Commands(self.root / 'sdk-evidence')
        installs = []
        def run(label, argv, **kwargs):
            if label.startswith('install-sdk-packages-'):
                installs.append(argv)
                if len(installs) == 2:
                    directory.mkdir(parents=True)
                    for name in ('source.properties', 'system.img', 'vendor.img', 'ramdisk.img', 'kernel-ranchu'):
                        (directory / name).write_bytes(b'fixture')
            return ''
        with patch.dict(os.environ, GITHUB_ACTIONS='true', RUNNER_ENVIRONMENT='github-hosted'), \
                patch.object(commands, 'run', side_effect=run):
            result = gate.install_integration_sdk_packages(commands, sdk / 'tools/bin', sdk, image_id)
        self.assertTrue(result['passed'])
        self.assertEqual(len(installs), 2)
        self.assertTrue(all('--sdk_root=' + str(sdk.resolve()) in argv for argv in installs))
        self.assertEqual(result['applicationTestsExecuted'], 0)
        self.assertEqual(result['emulatorsStarted'], 0)

    def test_sdk_setup_repairs_metadata_only_install_before_acceptance(self):
        sdk = self.root / 'sdk'
        image_id = 'system-images;android-36;google_apis;x86_64'
        commands = gate.Commands(self.root / 'evidence')
        def restore(*args):
            directory = sdk / Path(*image_id.split(';'))
            directory.mkdir(parents=True)
            for name in ('source.properties', 'system.img', 'vendor.img', 'ramdisk.img', 'kernel-ranchu'):
                (directory / name).write_bytes(b'verified fixture')
            return {'fixture': True}
        with patch.dict(os.environ, GITHUB_ACTIONS='true', RUNNER_ENVIRONMENT='github-hosted'), \
                patch.object(commands, 'run', return_value=''), \
                patch.object(gate, 'repair_partial_native_image', side_effect=restore) as repair:
            result = gate.install_integration_sdk_packages(commands, sdk / 'tools/bin', sdk, image_id)
        repair.assert_called_once_with(commands, sdk.resolve(), image_id)
        self.assertTrue(result['passed'])
        self.assertEqual(len(result['attempts']), 3)
        self.assertEqual(result['applicationTestsExecuted'], 0)

    def test_sdk_setup_failed_commands_cannot_pass_even_with_files(self):
        sdk = self.root / 'sdk'
        image_id = 'system-images;android-36;google_apis;x86_64'
        directory = sdk / Path(*image_id.split(';'))
        directory.mkdir(parents=True)
        for name in ('source.properties', 'system.img', 'vendor.img', 'ramdisk.img', 'kernel-ranchu'):
            (directory / name).write_bytes(b'fixture')
        commands = gate.Commands(self.root / 'sdk-evidence')
        def run(label, argv, **kwargs):
            if label.startswith('install-sdk-packages-'):
                raise RuntimeError('download failed')
            return ''
        with patch.dict(os.environ, GITHUB_ACTIONS='true', RUNNER_ENVIRONMENT='github-hosted'), \
                patch.object(commands, 'run', side_effect=run) as call:
            with self.assertRaisesRegex(RuntimeError, 'complete files'):
                gate.install_integration_sdk_packages(commands, sdk / 'tools/bin', sdk, image_id)
        result = json.loads((commands.evidence / 'native-sdk-provisioning.json').read_text())
        self.assertFalse(result['passed'])
        self.assertEqual(len(result['attempts']), 3)
        self.assertEqual(call.call_count, 9)
        self.assertTrue(all(not attempt['commandSucceeded'] for attempt in result['attempts']))

    def test_sdk_setup_rejects_non_hosted_before_commands(self):
        commands = gate.Commands(self.root / 'sdk-evidence')
        with patch.dict(os.environ, GITHUB_ACTIONS='true', RUNNER_ENVIRONMENT='self-hosted'), \
                patch.object(commands, 'run') as call:
            with self.assertRaisesRegex(RuntimeError, 'disposable hosted'):
                gate.install_integration_sdk_packages(commands, self.root, self.root, 'unused')
        call.assert_not_called()

    def test_selected_case_runs_once_and_does_not_claim_the_full_matrix(self):
        calls = []
        def launch(case, ordinal, commands):
            calls.append((case, ordinal))
            return {'passed': True, 'ownedEmulatorStopped': True,
                    'ownedLogCollectorStopped': True, 'ownedAdbServerStopped': True}
        result = gate.execute_integration_cases(gate.Commands(self.root / 'one-host'),
                    self.integration_source(), launch, case_index=5)
        self.assertEqual(calls, [(gate.INTEGRATION_CASES[4], 5)])
        self.assertEqual(result['expectedTests'], 6)
        self.assertEqual(result['expectedInvocations'], 1)
        self.assertEqual(result['caseOrdinals'], [5])
        self.assertEqual(result['notRun'], [])

    def test_adb_alignment_preserves_original_and_requires_exact_binary(self):
        sdk = self.root / 'sdk'
        destination = sdk / 'platform-tools/adb'
        destination.parent.mkdir(parents=True)
        destination.write_bytes(b'original SDK executable')
        pinned = self.root / 'pinned-adb'
        pinned.write_bytes(b'verified pinned executable')
        commands = gate.Commands(self.root / 'alignment')
        with patch.dict(os.environ, GITHUB_ACTIONS='true', RUNNER_ENVIRONMENT='github-hosted',
                        RUNNER_TEMP=str(self.root)), patch.object(gate.shutil, 'copystat',
                        side_effect=PermissionError('SDK metadata is owned by another account')), \
                        patch.object(commands, 'run', return_value=
                        'Android Debug Bridge version 1.0.41\nVersion 36.0.2-14143358'):
            result = gate.align_flutter_adb(commands, sdk, pinned)
            self.assertTrue(result['passed'])
            self.assertEqual(destination.read_bytes(), pinned.read_bytes())
            self.assertEqual(Path(result['originalBackup']).read_bytes(), b'original SDK executable')
            self.assertEqual(result['originalMode'], result['alignedMode'])
            with self.assertRaisesRegex(RuntimeError, 'backup already exists'):
                gate.align_flutter_adb(commands, sdk, pinned)

    def test_adb_alignment_rejects_local_or_self_hosted_before_any_write(self):
        for actions, environment in (('false', 'github-hosted'), ('true', 'self-hosted'), ('', '')):
            with patch.dict(os.environ, GITHUB_ACTIONS=actions, RUNNER_ENVIRONMENT=environment), \
                    patch.object(gate.shutil, 'copyfile') as copy:
                with self.assertRaisesRegex(RuntimeError, 'disposable GitHub-hosted'):
                    gate.align_flutter_adb(None, self.root / 'sdk', self.root / 'pinned')
                copy.assert_not_called()

    def test_adb_alignment_rejects_corrupt_copy(self):
        sdk = self.root / 'sdk'
        destination = sdk / 'platform-tools/adb'
        destination.parent.mkdir(parents=True)
        destination.write_bytes(b'original')
        pinned = self.root / 'pinned-adb'
        pinned.write_bytes(b'pinned')
        commands = gate.Commands(self.root / 'alignment')
        with patch.dict(os.environ, GITHUB_ACTIONS='true', RUNNER_ENVIRONMENT='github-hosted',
                        RUNNER_TEMP=str(self.root)), patch.object(gate.shutil, 'copyfile'):
            with self.assertRaisesRegex(RuntimeError, 'differs from the owned server'):
                gate.align_flutter_adb(commands, sdk, pinned)
        self.assertFalse((commands.evidence / 'flutter-adb-alignment.json').exists())

    def test_fixture_preparation_rejects_failed_isolation_and_any_transport_gap(self):
        for failing_step in ('fixture-wifi-readback', 'fixture-airplane-readback', 'fixture-settle-health-3', None):
            with tempfile.TemporaryDirectory() as directory:
                commands = gate.Commands(directory)
                health = []
                def run(label, argv, **kwargs):
                    if label == 'fixture-airplane-readback':
                        return 'disabled' if label == failing_step else 'enabled'
                    if label.endswith('readback'):
                        return '1' if label == failing_step else '0'
                    return 'MemAvailable: 1024000 kB'
                def sample(commands, adb, process, label):
                    health.append(label)
                    if label == failing_step:
                        raise RuntimeError('device offline')
                with patch.object(commands, 'run', side_effect=run), \
                        patch.object(gate, 'guest_health', side_effect=sample), \
                        patch.object(gate.time, 'sleep'), \
                        patch.object(Path, 'read_text', return_value='fixture host resource record'):
                    if failing_step is None:
                        result = gate.prepare_fixture_guest(commands, ['adb'], None)
                        self.assertTrue(result['passed'])
                        self.assertEqual(len(result['samples']), 7)
                    else:
                        with self.assertRaises(RuntimeError):
                            gate.prepare_fixture_guest(commands, ['adb'], None)
                receipt = gate.read_json(Path(directory) / 'fixture-preparation.json')
                self.assertEqual(receipt['passed'], failing_step is None)
                self.assertEqual(receipt['applicationTestsExecuted'], 0)
                if failing_step == 'fixture-settle-health-3':
                    self.assertEqual(len(health), 4)  # No reconnect or repeated health attempt.

    def test_adbd_restart_requires_actual_root_and_rejects_other_failures(self):
        cases = [(0, 'restarting adbd as root', '0', True),
                 (1, 'adb: unable to connect for root: closed', '0', True),
                 (1, 'adb: unable to connect for root: closed', '2000', False),
                 (1, 'adbd cannot run as root in production builds', '0', False),
                 (0, 'restarting adbd as root', '2000', False)]
        for index, (code, output, uid, passed) in enumerate(cases):
            with tempfile.TemporaryDirectory() as directory:
                commands = gate.Commands(directory)
                def run(label, argv, **kwargs):
                    commands.records.append({'label': label, 'exitCode': code if label == 'root-owned-userdebug-adb' else 0})
                    return output if label == 'root-owned-userdebug-adb' else uid if label == 'root-readback' else ''
                with patch.object(commands, 'run', side_effect=run):
                    if passed:
                        self.assertTrue(gate.root_userdebug_guest(commands, ['adb', '-s', 'emulator-5554'])['verifiedRoot'])
                    else:
                        with self.assertRaises(RuntimeError):
                            gate.root_userdebug_guest(commands, ['adb', '-s', 'emulator-5554'])
                self.assertEqual(gate.read_json(Path(directory) / 'root-readback.json')['verifiedRoot'], passed)

    def test_native_emulator_pin_rejects_corrupt_download_before_extraction(self):
        commands = gate.Commands(self.root / 'pin-evidence')
        labels = []
        def run(label, argv, **kwargs):
            labels.append(label)
            if label.startswith('download-'):
                Path(argv[-1]).write_bytes(b'corrupt download')
        with patch.dict(os.environ, RUNNER_TEMP=str(self.root)), patch.object(commands, 'run', side_effect=run):
            with self.assertRaisesRegex(RuntimeError, 'checksum mismatch'):
                gate.install_native_emulator(commands)
        self.assertEqual(labels, ['download-pinned-native-emulator'])
        self.assertFalse((commands.evidence / 'native-emulator-pin.json').exists())

    def test_native_emulator_pin_rejects_wrong_executable_version(self):
        commands = gate.Commands(self.root / 'pin-evidence')
        with patch.dict(os.environ, RUNNER_TEMP=str(self.root)), \
                patch.object(gate, 'digest', return_value=gate.NATIVE_EMULATOR_SHA256), \
                patch.object(commands, 'run', return_value='36.6.11.0 build 15507667'):
            with self.assertRaisesRegex(RuntimeError, 'Unexpected pinned emulator version'):
                gate.install_native_emulator(commands)
        self.assertFalse((commands.evidence / 'native-emulator-pin.json').exists())

    def test_native_build_preparation_is_compile_only_and_requires_an_apk(self):
        source = self.integration_source()
        commands = gate.Commands(self.root / 'prepare')
        with patch.object(gate.native_instrumentation, 'prepare', return_value={'file': 'app_startup_test.dart'}) as prepare:
            receipt = gate.prepare_native_build(commands, source, self.root, 1)
        prepare.assert_called_once_with(commands, source, self.root, 'app_startup_test.dart')
        self.assertTrue(receipt['passed'])
        self.assertEqual(receipt['applicationTestsExecuted'], 0)
        self.assertEqual(receipt['emulatorsStarted'], 0)

    def test_native_build_preparation_never_accepts_failed_or_missing_output(self):
        source = self.integration_source()
        for index, side_effect in enumerate((RuntimeError('compile failed'), None)):
            commands = gate.Commands(self.root / f'prepare-fail-{index}')
            with patch.object(gate.native_instrumentation, 'prepare', side_effect=RuntimeError('compile failed')), self.assertRaises(RuntimeError):
                gate.prepare_native_build(commands, source, self.root, 1)
            self.assertFalse(gate.read_json(commands.evidence / 'native-build-preparation.json')['passed'])

    @contextmanager
    def kvm_fixture(self, commands, *, accessible=(False, True), fail_label=None,
                    acceleration="accel:\n0\nKVM (version 12) is installed and usable.\naccel"):
        device = SimpleNamespace(st_mode=stat.S_IFCHR | 0o660, st_dev=1, st_ino=2,
                                 st_rdev=3, st_uid=0, st_gid=993)
        events = []
        def run(label, argv, **kwargs):
            events.append((label, argv))
            if label == fail_label:
                raise RuntimeError("synthetic command failure: " + label)
            return acceleration if label == "guest-acceleration-check" else "# retained ACL readback"
        with ExitStack() as stack:
            stack.enter_context(patch.object(Path, "lstat", return_value=device))
            stack.enter_context(patch.object(gate.os, "getuid", return_value=1001, create=True))
            stack.enter_context(patch.object(gate.os, "access", side_effect=accessible))
            stack.enter_context(patch.object(gate.os, "O_CLOEXEC", 0x80000, create=True))
            opened = stack.enter_context(patch.object(gate.os, "open", return_value=123))
            closed = stack.enter_context(patch.object(gate.os, "close"))
            stack.enter_context(patch.object(gate.os, "fstat", return_value=device))
            stack.enter_context(patch.object(commands, "run", side_effect=run))
            yield events, opened, closed

    def test_each_fresh_guest_reasserts_only_current_user_kvm_acl_after_drift(self):
        for ordinal in (1, 2):
            commands = gate.Commands(self.root / f"kvm-{ordinal}")
            with self.kvm_fixture(commands) as (events, opened, closed):
                result = gate.prepare_integration_kvm(commands, Path("emulator"))
                self.assertTrue(result["passed"])
                self.assertFalse(result["before"]["readWriteAccessible"])
                self.assertTrue(result["after"]["readWriteAccessible"])
                self.assertTrue(result["readWriteOpenSucceeded"])
                self.assertEqual([event[0] for event in events],
                                 ["kvm-acl-before", "restore-current-user-kvm-acl",
                                  "kvm-acl-after", "guest-acceleration-check"])
                self.assertEqual(events[1][1], ["sudo", "-n", "setfacl", "-m", "u:1001:rw", str(Path("/dev/kvm"))])
                opened.assert_called_once()
                closed.assert_called_once_with(123)
            self.assertTrue(gate.read_json(commands.evidence / "kvm-preparation.json")["passed"])

    def test_failed_kvm_acl_or_still_denied_access_never_checks_acceleration(self):
        for index, values in enumerate(({"fail_label": "restore-current-user-kvm-acl"},
                                        {"accessible": (False, False)})):
            commands = gate.Commands(self.root / f"kvm-denied-{index}")
            with self.kvm_fixture(commands, **values) as (events, opened, closed):
                with self.assertRaises(RuntimeError):
                    gate.prepare_integration_kvm(commands, Path("emulator"))
                self.assertNotIn("guest-acceleration-check", [event[0] for event in events])
                opened.assert_not_called()
                closed.assert_not_called()
            receipt = gate.read_json(commands.evidence / "kvm-preparation.json")
            self.assertFalse(receipt["passed"])
            self.assertIn("failure", receipt)

    def test_kvm_requires_real_device_open_and_positive_acceleration(self):
        for index, value in enumerate(("KVM is unusable", "KVM is not installed and usable.",
                                       "KVM permission denied", "")):
            commands = gate.Commands(self.root / f"kvm-bad-accel-{index}")
            with self.kvm_fixture(commands, acceleration=value) as (_, opened, closed):
                with self.assertRaisesRegex(RuntimeError, "Usable KVM"):
                    gate.prepare_integration_kvm(commands, Path("emulator"))
                opened.assert_called_once()
                closed.assert_called_once_with(123)
            self.assertFalse(gate.read_json(commands.evidence / "kvm-preparation.json")["passed"])
        commands = gate.Commands(self.root / "kvm-open-denied")
        with self.kvm_fixture(commands) as (events, opened, closed):
            opened.side_effect = PermissionError("synthetic access revoked after readback")
            with self.assertRaises(PermissionError):
                gate.prepare_integration_kvm(commands, Path("emulator"))
            self.assertNotIn("guest-acceleration-check", [event[0] for event in events])
            closed.assert_not_called()
        self.assertFalse(gate.read_json(commands.evidence / "kvm-preparation.json")["passed"])

    def test_kvm_rejects_wrong_device_type_and_recreated_open_target(self):
        commands = gate.Commands(self.root / "kvm-identity")
        with self.kvm_fixture(commands) as (events, _, closed):
            with patch.object(Path, "lstat", return_value=SimpleNamespace(st_mode=stat.S_IFREG)):
                with self.assertRaisesRegex(RuntimeError, "character device"):
                    gate.prepare_integration_kvm(commands, Path("emulator"))
            self.assertEqual(events, [])
            with patch.object(gate.os, "fstat", return_value=SimpleNamespace(st_dev=1, st_ino=999, st_rdev=3)):
                with self.assertRaisesRegex(RuntimeError, "changed between"):
                    gate.prepare_integration_kvm(commands, Path("emulator"))
            closed.assert_called_once_with(123)

    def test_kvm_preparation_fences_integration_launch_without_changing_strict_16kb(self):
        for mode in ("integration", "16kb"):
            commands = gate.Commands(self.root / ("launch-" + mode))
            events = []
            def preparation(*args):
                events.append("kvm")
                raise RuntimeError("synthetic KVM denied")
            def launch(*args, **kwargs):
                events.append("emulator")
                raise OSError("synthetic launch stopped; no native process")
            with patch.dict(os.environ, {"RUNNER_TEMP": str(self.root)}), \
                    patch.object(commands, "run"), patch.object(gate, "configure_avd", return_value={}), \
                    patch.object(gate, "digest", return_value="f" * 64), \
                    patch.object(gate, "prepare_integration_kvm", side_effect=preparation), \
                    patch.object(gate.subprocess, "Popen", side_effect=launch):
                result = gate.owned_android_guest(mode, self.root, self.root, commands, self.root,
                                                  self.root, Path("emulator"), "fixture", self.root)
            self.assertFalse(result["passed"])
            self.assertEqual(events, ["kvm"] if mode == "integration" else ["emulator"])

    def test_guest_physical_display_matches_each_reviewed_viewport(self):
        for viewport in ("320x640", "411x891"):
            config = self.root / (viewport + ".ini")
            config.write_text("hw.lcd.width=320\nhw.lcd.height=640\ncustom=preserved\n")
            settings = gate.configure_avd(config, viewport)
            self.assertEqual((settings["hw.lcd.width"], settings["hw.lcd.height"]),
                             tuple(gate.physical_viewport(viewport).split("x")))
            self.assertEqual(settings["hw.lcd.density"], "160")
            self.assertIn("custom=preserved", config.read_text())
        with self.assertRaisesRegex(RuntimeError, "Unreviewed native viewport"):
            gate.configure_avd(config, "640x320")

    def test_tall_logical_viewport_requires_separate_physical_and_override_proof(self):
        result = gate.verify_viewport_readback('Physical size: 412x891\nOverride size: 411x891', '411x891')
        self.assertEqual(result, {'logicalViewport': '411x891', 'physicalViewport': '412x891'})
        for value in ('Physical size: 412x891', 'Physical size: 320x640\nOverride size: 411x891',
                      'Physical size: 412x891\nOverride size: 410x891', ''):
            with self.assertRaises(RuntimeError):
                gate.verify_viewport_readback(value, '411x891')
        self.assertEqual(gate.verify_viewport_readback('Physical size: 320x640', '320x640')['logicalViewport'], '320x640')

    def test_native_adb_pin_rejects_checksum_and_protocol_mismatch(self):
        expected = '3afdea91441815ab41254193df0343d92c1b1c0d0237165c3a345c8af8891c31'
        version = 'Android Debug Bridge version 1.0.41\nVersion 36.0.2-14143358'
        for index, (checksum, output, passed) in enumerate(((expected, version, True),
                                                          ('0' * 64, version, False),
                                                          (expected, 'Version 37.0.1', False))):
            temporary = self.root / ('adb-pin-' + str(index))
            temporary.mkdir()
            commands = gate.Commands(temporary / 'evidence')
            with patch.dict(os.environ, {'RUNNER_TEMP': str(temporary)}), \
                    patch.object(gate, 'digest', return_value=checksum), \
                    patch.object(commands, 'run', return_value=output) as run:
                if passed:
                    executable = gate.install_native_adb(commands)
                    self.assertTrue(executable.is_relative_to(temporary))
                    self.assertEqual(gate.read_json(commands.evidence / 'native-adb-pin.json')['sha256'], expected)
                else:
                    with self.assertRaises(RuntimeError):
                        gate.install_native_adb(commands)
                if checksum != expected:
                    self.assertEqual([call.args[0] for call in run.call_args_list], ['download-pinned-native-adb'])

    def integration_source(self):
        source = self.root / "app-source"
        (source / "integration_test").mkdir(parents=True, exist_ok=True)
        for filename in gate.SOURCE_FILES:
            (source / "integration_test" / filename).touch()
        return source

    def test_fresh_guests_keep_all_five_invocations_without_retrying_a_failure(self):
        calls = []
        def launch(case, ordinal, commands):
            calls.append((case, ordinal, commands.evidence))
            return {"passed": ordinal != 2, "ownedEmulatorStopped": True, "ownedLogCollectorStopped": True,
                    "ownedAdbServerStopped": True}
        commands = gate.Commands(self.root / "five-guests")
        with self.assertRaisesRegex(RuntimeError, "invocations failed"):
            gate.execute_integration_cases(commands, self.integration_source(), launch)
        self.assertEqual([value[0][2] for value in calls], [1, 6, 1, 1, 6])
        self.assertEqual(len({value[2] for value in calls}), 5)
        result = gate.read_json(commands.evidence / "android-result.json")
        self.assertFalse(result["passed"])
        self.assertEqual(result["completedInvocations"], 5)
        self.assertEqual(result["notRun"], [])
        self.assertFalse(result["runs"][1]["passed"])

    def test_failed_owned_guest_or_collector_cleanup_prevents_next_guest(self):
        for failed in ("ownedEmulatorStopped", "ownedLogCollectorStopped", "ownedAdbServerStopped"):
            calls = []
            def launch(case, ordinal, commands):
                calls.append(ordinal)
                return {"passed": False, "ownedEmulatorStopped": True,
                        "ownedLogCollectorStopped": True, "ownedAdbServerStopped": True, failed: False}
            commands = gate.Commands(self.root / failed)
            with self.subTest(failed=failed), self.assertRaisesRegex(RuntimeError, "cleanup was not proved"):
                gate.execute_integration_cases(commands, self.integration_source(), launch)
            self.assertEqual(calls, [1])
            result = gate.read_json(commands.evidence / "android-result.json")
            self.assertFalse(result["passed"])
            self.assertEqual(len(result["notRun"]), 4)

    def test_missing_collector_cleanup_proof_blocks_further_guests(self):
        calls = []
        def launch(case, ordinal, commands):
            calls.append(ordinal)
            return {"passed": False, "ownedEmulatorStopped": True}
        commands = gate.Commands(self.root / "missing-collector-proof")
        with self.assertRaisesRegex(RuntimeError, "cleanup was not proved"):
            gate.execute_integration_cases(commands, self.integration_source(), launch)
        self.assertEqual(calls, [1])
        result = gate.read_json(commands.evidence / "android-result.json")
        self.assertFalse(result["passed"])
        self.assertEqual(len(result["notRun"]), 4)

    def test_health_rejects_offline_dead_or_unowned_guest_before_tests(self):
        class Process:
            args = ['emulator', '-avd', 'ChronoSpark_Final_integration_01', '-port', '5554']
            pid = 123
            code = None
            def poll(self):
                return self.code
        process = Process()
        commands = gate.Commands(self.root / "health")
        for serial, state, code in (("emulator-5554", "offline", None),
                                    ("emulator-5554", "device", 1), ("physical-device", "device", None)):
            process.code = code
            with patch.object(commands, "run", return_value=state) as run:
                with self.subTest(serial=serial, state=state, code=code), self.assertRaises(RuntimeError):
                    gate.guest_health(commands, ["adb", "-s", serial], process, "health")
                self.assertLessEqual(run.call_count, 1)
                self.assertFalse(gate.read_json(commands.evidence / "health.json")["passed"])
        process.code = None
        with patch.object(commands, "run", side_effect=["device", "1", "CHRONOSPARK_GUEST_READY"]):
            self.assertTrue(gate.guest_health(commands, ["adb", "-s", "emulator-5554"], process, "healthy")["passed"])
        process.args[-1] = '5586'
        with patch.object(commands, "run", side_effect=["device", "1", "CHRONOSPARK_GUEST_READY"]):
            self.assertTrue(gate.guest_health(commands, ["adb", "-s", "emulator-5586"], process, "isolated")["passed"])
        with patch.object(commands, "run") as run, self.assertRaisesRegex(RuntimeError, 'unowned'):
            gate.guest_health(commands, ["adb", "-s", "emulator-5554"], process, "wrong-port")
        run.assert_not_called()

    def png(self):
        def chunk(kind, payload):
            return struct.pack(">I", len(payload)) + kind + payload + struct.pack(">I", zlib.crc32(kind + payload) & 0xffffffff)
        return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", 1, 1, 8, 2, 0, 0, 0)) +
                chunk(b"IDAT", zlib.compress(b"\x00\x00\x00\x00")) + chunk(b"IEND", b""))

    def test_png_capture_requires_complete_bytes_and_original_success_exit(self):
        self.assertEqual(gate.verify_png(self.png()), [1, 1])
        for value in (b"", self.png()[:20], self.png()[:-1], self.png().replace(b"IDAT", b"XDAT")):
            with self.subTest(bytes=len(value)), self.assertRaises(RuntimeError):
                gate.verify_png(value)
        for index, (code, data) in enumerate(((1, self.png()), (0, b""), (0, self.png()))):
            def run(argv, **kwargs):
                kwargs["stdout"].write(data)
                return subprocess.CompletedProcess(argv, code, stderr=b"retained diagnostic")
            commands = gate.Commands(self.root / ("png-" + str(index)))
            with patch.object(gate.subprocess, "run", side_effect=run):
                if index < 2:
                    with self.assertRaises(RuntimeError):
                        gate.capture_guest_png(commands, ["adb", "-s", "emulator-5554"], "screen", "1x1")
                else:
                    self.assertTrue(gate.capture_guest_png(commands, ["adb", "-s", "emulator-5554"], "screen", "1x1")["valid"])
            receipt = gate.read_json(commands.evidence / "screen.json")
            self.assertEqual(receipt["exitCode"], code)
            self.assertEqual(receipt["valid"], index == 2)

    def test_capture_accepts_only_declared_logical_or_physical_size(self):
        for index, (size, expected) in enumerate((([411, 891], 'logical'), ([412, 891], 'physical'),
                                                 ([410, 891], None), ([891, 412], None), ([320, 640], None))):
            def run(argv, **kwargs):
                kwargs['stdout'].write(self.png())
                return subprocess.CompletedProcess(argv, 0, stderr=b'')
            commands = gate.Commands(self.root / ('capture-space-' + str(index)))
            with patch.object(gate.subprocess, 'run', side_effect=run), patch.object(gate, 'verify_png', return_value=size):
                if expected:
                    receipt = gate.capture_guest_png(commands, ['adb'], 'screen', '411x891', '412x891')
                    self.assertEqual(receipt['captureSpace'], expected)
                else:
                    with self.assertRaisesRegex(RuntimeError, 'Screenshot dimensions'):
                        gate.capture_guest_png(commands, ['adb'], 'screen', '411x891', '412x891')
            receipt = gate.read_json(commands.evidence / "screen.json")
            self.assertEqual(receipt["valid"], expected is not None)

    def test_native_case_requires_six_auth_tests_and_preserves_failure_captures(self):
        class Collector:
            pid = 123
            returncode = None
            def poll(self):
                return self.returncode
            def terminate(self):
                self.returncode = -15
            def wait(self, timeout):
                return self.returncode
        original_open = Path.open
        for index, (count, code, body) in enumerate(((6, 0, ""), (4, 0, ""), (6, 1, ""),
                                                   (6, 0, "FATAL EXCEPTION: main\n"), (6, 0, ""))):
            commands = gate.Commands(self.root / ("case-" + str(index)))
            collector = Collector()
            def open_file(path, mode="r", *args, **kwargs):
                if index == 4 and path.name == "continuous-logcat.log" and mode == "rb":
                    raise OSError("fixture readback failure")
                return original_open(path, mode, *args, **kwargs)
            def run(label, argv, **kwargs):
                commands.records.append({"label": label, "exitCode": code if label.startswith("auth_flow") else 0})
                if label in ('viewport-readback', 'post-test-viewport'):
                    return 'Physical size: 320x640\nOverride size: 320x640'
                if label in ("begin-test-log", "end-test-log"):
                    with (commands.evidence / "continuous-logcat.log").open("a", encoding="utf-8") as stream:
                        stream.write(argv[-1] + "\n" + body)
                return ""
            def execute(commands, source, adb, filename, expected, label):
                commands.records.append({'label': label, 'exitCode': code})
                if code:
                    raise RuntimeError('instrumentation command failed')
                return {'totals': {'total': count, 'passed': count, 'failed': 0, 'error': 0, 'skipped': 0},
                        'completedTestNames': [str(i) for i in range(count)]}
            with patch.object(commands, "run", side_effect=run), patch.object(gate, "guest_health"), \
                    patch.object(gate.native_instrumentation, "execute", side_effect=execute), \
                    patch.object(gate, "capture_guest_png") as screenshots, \
                    patch.object(gate.subprocess, "Popen", return_value=collector), \
                    patch.object(Path, "open", open_file):
                result = gate.integration(commands, self.root, ["adb", "-s", "emulator-5554"], Collector(),
                                          ("auth_flow_integration_test.dart", "320x640", 6))
            self.assertEqual(result["passed"], index == 0)
            self.assertEqual(result["runnerExitCode"], code)
            self.assertEqual(result["debugTransport"], "android-instrumentation")
            self.assertEqual(screenshots.call_count, 2)
            self.assertTrue(result["ownedLogCollectorStopped"])
            self.assertEqual(collector.returncode, -15)
            if index == 4:
                self.assertTrue(any("Log marker readback failed" in failure for failure in result["failures"]))
            self.assertTrue((commands.evidence / "integration-case-result.json").exists())

    def test_integration_lifecycle_scan_keeps_native_fatals_without_false_teardown_failure(self):
        lifecycle = "Process " + gate.PACKAGE + " has died"
        self.assertEqual(gate.fatal_lines(lifecycle), [lifecycle])
        self.assertEqual(gate.fatal_lines(lifecycle, include_process_exit=False), [])
        fatal = "FATAL EXCEPTION: main; " + lifecycle
        self.assertEqual(gate.fatal_lines(fatal, include_process_exit=False), [fatal])
        self.assertEqual(gate.fatal_lines("ANR in " + gate.PACKAGE, include_process_exit=False), ["ANR in " + gate.PACKAGE])

    def test_threadtime_flutter_errors_fail_both_runtime_scan_modes(self):
        lines = ["09-09 13:16:30.123  5620  5655 E flutter : Unhandled Exception: StateError",
                 "09-09 13:16:30.124  5620  5655 E flutter : [ERROR:flutter/runtime/dart_vm_initializer.cc(40)] failure"]
        benign = "09-09 13:16:30.125  5620  5655 I flutter : integration fixture ready"
        for include_process_exit in (True, False):
            self.assertEqual(gate.fatal_lines("\n".join(lines + [benign]),
                                             include_process_exit=include_process_exit), lines)

    def test_reviewed_test_delta_requires_all_four_paths_and_no_product_change(self):
        rows = [f":100644 100644 {'a' * 40} {'b' * 40} M\0{path}\0"
                for path in sorted(gate.REVIEWED_TEST_REPAIR_PATHS)]
        raw = "".join(rows)
        entries = gate.validate_test_only_delta(raw, gate.REVIEWED_TEST_REPAIR_BASE, "c" * 40)
        self.assertEqual(len(entries), 4)
        for invalid in ("", "".join(rows[:-1]), raw + rows[0],
                        raw + f":100644 100644 {'a' * 40} {'b' * 40} M\0lib/main.dart\0",
                        raw.replace("100644 100644", "100644 100755", 1),
                        raw.replace(" M\0", " D\0", 1),
                        raw.replace(" M\0", " R100\0", 1), raw.rstrip("\0"),
                        raw.replace("check_architecture.ps1", "../check_architecture.ps1")):
            with self.subTest(invalid=invalid), self.assertRaises(RuntimeError):
                gate.validate_test_only_delta(invalid, gate.REVIEWED_TEST_REPAIR_BASE, "c" * 40)
        for base, target in (("a" * 40, "c" * 40),
                             (gate.REVIEWED_TEST_REPAIR_BASE, "branch"),
                             (gate.REVIEWED_TEST_REPAIR_BASE, gate.REVIEWED_TEST_REPAIR_BASE)):
            with self.subTest(base=base, target=target), self.assertRaises(RuntimeError):
                gate.validate_test_only_delta(raw, base, target)

    def test_emulator_library_preflight_rejects_missing_dependencies_and_empty_output(self):
        gate.verify_emulator_library_listing("libpulse.so.0 => /usr/lib/libpulse.so.0 (0x123)\nlibc.so.6 => /usr/lib/libc.so.6 (0x456)")
        for listing in ("", "not a dynamic executable", "libc.so.6 => /usr/lib/libc.so.6\nlibpulse.so.0 => not found"):
            with self.subTest(listing=listing), self.assertRaises(RuntimeError):
                gate.verify_emulator_library_listing(listing)

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.source = "a" * 40
        self.build_tooling = "b" * 40
        self.repo = "ghostheart5/fantastic-guacamole"
        self.run_id = "123"
        self.run = {"id": 123, "repository": {"full_name": self.repo},
                    "head_repository": {"full_name": self.repo},
                    "head_branch": "fix/app-only-readiness-priority2-20260902",
                    "path": ".github/workflows/android-candidate-build.yml",
                    "event": "workflow_dispatch", "status": "completed", "conclusion": "success",
                    "head_sha": self.build_tooling, "run_attempt": 2}
        self.aab = b"Fixture bytes; real bundle validity belongs to the separate signed-artifact runner."
        self.aab_sha = hashlib.sha256(self.aab).hexdigest()
        self.candidate = {"sourceSha": self.source, "toolingSha": self.build_tooling,
                          "buildRunId": self.run_id, "runAttempt": "2", "package": gate.PACKAGE,
                          "versionName": "4.1.0", "versionCode": 2026083022,
                          "aabSha256": self.aab_sha, "uploadSignerSha256": "C" * 64}
        self.licenses = {"success": True, "artifactSha256": self.aab_sha}
        self.artifact = {"id": 456, "name": f"chronospark-candidate-{self.source}-123-2", "expired": False,
                         "workflow_run": {"id": 123, "head_sha": self.build_tooling}}
        self.zip_path = self.root / "candidate.zip"

    def archive(self, *, duplicate=False):
        with zipfile.ZipFile(self.zip_path, "w") as archive:
            archive.writestr("candidate.json", json.dumps(self.candidate))
            archive.writestr("additional-license-verification.json", json.dumps(self.licenses))
            archive.writestr("app-release.aab", self.aab)
            if duplicate:
                with warnings.catch_warnings():
                    warnings.simplefilter("ignore", UserWarning)
                    archive.writestr("candidate.json", json.dumps(self.candidate))
        self.artifact.update(size_in_bytes=self.zip_path.stat().st_size,
                             digest="sha256:" + gate.digest(self.zip_path))

    def verify(self):
        return gate.verify_candidate(self.zip_path, self.run, self.artifact,
                                     self.source, self.run_id, self.repo)

    def test_completed_candidate_uses_build_tooling_identity_not_validation_head(self):
        self.archive()
        result = self.verify()
        self.assertEqual(result["candidateToolingSha"], self.build_tooling)
        self.assertEqual(result["sourceSha"], self.source)
        self.assertEqual(result["aabSha256"], self.aab_sha)

    def test_wrong_source_run_attempt_and_tooling_are_rejected(self):
        for key, value in (("sourceSha", "d" * 40), ("buildRunId", "124"),
                           ("runAttempt", "1"), ("toolingSha", "e" * 40),
                           ("package", "wrong.package")):
            with self.subTest(key=key):
                original = self.candidate[key]
                self.candidate[key] = value
                self.archive()
                with self.assertRaises(RuntimeError):
                    self.verify()
                self.candidate[key] = original

    def test_other_workflow_fork_unfinished_and_unsuccessful_runs_are_rejected(self):
        self.archive()
        for key, value in (("path", ".github/workflows/ci.yml"), ("event", "pull_request"),
                           ("head_branch", "unreviewed-branch"),
                           ("status", "in_progress"), ("conclusion", "failure"),
                           ("head_repository", {"full_name": "other/repo"})):
            with self.subTest(key=key):
                original = self.run[key]
                self.run[key] = value
                with self.assertRaises(RuntimeError):
                    self.verify()
                self.run[key] = original

    def test_expired_wrong_attempt_missing_digest_and_other_run_artifacts_fail(self):
        self.archive()
        for key, value in (("expired", True), ("name", self.artifact["name"][:-1] + "1"),
                           ("digest", ""), ("workflow_run", {"id": 124, "head_sha": self.build_tooling})):
            with self.subTest(key=key):
                original = self.artifact[key]
                self.artifact[key] = value
                with self.assertRaises(RuntimeError):
                    self.verify()
                self.artifact[key] = original

    def test_tampered_download_fails_before_trusting_manifest(self):
        self.archive()
        with self.zip_path.open("ab") as stream:
            stream.write(b"unexpected bytes")
        with self.assertRaisesRegex(RuntimeError, "ZIP digest mismatch"):
            self.verify()

    def test_actual_aab_hash_is_required_even_when_api_zip_digest_matches(self):
        self.aab = b"A different artifact payload"
        self.archive()
        with self.assertRaisesRegex(RuntimeError, "AAB SHA256 mismatch"):
            self.verify()

    def test_missing_or_mismatched_license_success_is_rejected(self):
        for value in ({}, {"success": False, "artifactSha256": self.aab_sha},
                      {"success": True, "artifactSha256": "f" * 64}):
            with self.subTest(value=value):
                self.licenses = value
                self.archive()
                with self.assertRaisesRegex(RuntimeError, "license"):
                    self.verify()

    def test_duplicate_artifact_entries_are_rejected(self):
        self.archive(duplicate=True)
        with self.assertRaisesRegex(RuntimeError, "Duplicate"):
            self.verify()

    def test_source_and_run_inputs_must_be_immutable_and_numeric(self):
        for source, run in (("main", self.run_id), (self.source, "123/attempts"), ("A" * 40, self.run_id)):
            with self.subTest(source=source, run=run), self.assertRaises(RuntimeError):
                gate.validate_run(self.run, source, run, self.repo)

    def terminal(self):
        return {"finalSuccess": True, "exitCode": 0, "terminalCompletion": True,
                "terminalSuccess": True, "timedOut": False, "launchFailed": False,
                "totals": {"total": 6, "passed": 6, "failed": 0, "error": 0, "skipped": 0},
                "completedTests": 6, "reportParseErrors": []}

    def test_terminal_contract_accepts_complete_execution(self):
        path = self.root / "manifest.json"
        gate.write_json(path, self.terminal())
        self.assertEqual(gate.verify_terminal(path)["passed"], 6)

    def test_terminal_zero_skips_errors_partial_completion_and_original_exit_fail(self):
        variants = []
        for key, value in (("exitCode", 1), ("timedOut", True), ("completedTests", 5),
                           ("terminalCompletion", False), ("reportParseErrors", ["bad JSON"])):
            changed = self.terminal()
            changed[key] = value
            variants.append(changed)
        for key, value in (("total", 0), ("skipped", 1), ("failed", 1), ("error", 1)):
            changed = self.terminal()
            changed["totals"][key] = value
            variants.append(changed)
        for index, receipt in enumerate(variants):
            with self.subTest(index=index):
                path = self.root / "manifest.json"
                gate.write_json(path, receipt)
                with self.assertRaises(RuntimeError):
                    gate.verify_terminal(path)

    def test_runtime_error_scan_catches_native_flutter_and_app_anr_failures(self):
        failures = ["FATAL EXCEPTION: main", "Fatal signal 11 (SIGSEGV)",
                    "E/flutter: Unhandled Exception: StateError", "MissingPluginException(No impl)",
                    "ANR in " + gate.PACKAGE, "Process " + gate.PACKAGE + " has died"]
        self.assertEqual(gate.fatal_lines("\n".join(failures)), failures)
        self.assertEqual(gate.fatal_lines("ActivityTaskManager: Displayed " + gate.PACKAGE), [])

    def test_owned_avd_preserves_image_but_requires_muted_small_software_gpu(self):
        path = self.root / "config.ini"
        path.write_text("image.sysdir.1=system-images/android-37.1/google_apis_ps16k/x86_64/\nhw.audioInput=yes\n")
        result = gate.configure_avd(path)
        self.assertEqual(result["image.sysdir.1"], "system-images/android-37.1/google_apis_ps16k/x86_64/")
        self.assertEqual(result["hw.audioInput"], "no")
        self.assertEqual(result["hw.audioOutput"], "no")
        self.assertEqual(result["hw.ramSize"], "2048")
        self.assertEqual(result["hw.cpu.ncore"], "2")
        self.assertEqual(result["hw.gpu.mode"], "swiftshader")

    def test_rendered_welcome_requires_brand_and_visible_enabled_real_action(self):
        path = self.root / "window.xml"
        template = '<hierarchy><node content-desc="CHRONOSPARK"/><node content-desc="CONTINUE TO LOGIN" enabled="{enabled}" clickable="true" bounds="{bounds}"/></hierarchy>'
        path.write_text(template.format(enabled="true", bounds="[30,500][290,560]"))
        gate.verify_rendered_onboarding(path)
        for enabled, bounds in (("false", "[30,500][290,560]"), ("true", "[30,620][290,690]")):
            path.write_text(template.format(enabled=enabled, bounds=bounds))
            with self.assertRaises(RuntimeError):
                gate.verify_rendered_onboarding(path)
        path.write_text('<hierarchy><node content-desc="Splash screen"/></hierarchy>')
        with self.assertRaises(RuntimeError):
            gate.verify_rendered_onboarding(path)

    def test_standalone_junit_requires_one_passing_executed_case(self):
        path = self.root / "maestro.xml"
        path.write_text('<testsuites tests="1" failures="0" errors="0" skipped="0"><testsuite tests="1" failures="0"><testcase name="03-onboarding-tutorial" status="SUCCESS"/></testsuite></testsuites>')
        self.assertEqual(gate.verify_one_maestro_case(path)["testCases"], 1)

    def test_standalone_junit_rejects_skips_errors_empty_multiple_and_false_counters(self):
        for xml in (
            '<testsuite tests="0"/>',
            '<testsuite><testcase/><testcase/></testsuite>',
            '<testsuite><testcase><skipped/></testcase></testsuite>',
            '<testsuite><testcase><failure/></testcase></testsuite>',
            '<testsuite><testcase><error/></testcase></testsuite>',
            '<testsuite tests="2"><testcase/></testsuite>',
            '<testsuite errors="1"><testcase/></testsuite>',
            '<testsuite><testcase status="notrun"/></testsuite>',
        ):
            with self.subTest(xml=xml):
                path = self.root / "maestro.xml"
                path.write_text(xml)
                with self.assertRaises(RuntimeError):
                    gate.verify_one_maestro_case(path)

    def test_native_login_handoff_cannot_be_a_welcome_or_blank_screen(self):
        path = self.root / "login.xml"
        path.write_text('<hierarchy><node text="ENTER SYSTEM"/><node content-desc="Email address"/><node content-desc="Password"/></hierarchy>')
        gate.verify_rendered_login(path)
        for text in ('<hierarchy/>', '<hierarchy><node text="ENTER SYSTEM"/></hierarchy>',
                     '<hierarchy><node text="ENTER SYSTEM"/><node text="Email address Password CONTINUE TO LOGIN"/></hierarchy>'):
            path.write_text(text)
            with self.assertRaises(RuntimeError):
                gate.verify_rendered_login(path)

    def test_onboarding_stop_waits_for_terminating_process_without_repeating_force_stop(self):
        class FakeCommands:
            evidence = self.root
            records = []
            outputs = iter(["", "4026", "4026", ""])

            def run(self, label, argv, **kwargs):
                self.records.append({"label": label, "exitCode": 0})
                return next(self.outputs)

        commands = FakeCommands()
        with patch.object(gate.time, "sleep"):
            result = gate.stop_owned_app_for_onboarding(commands, ["fake-adb", "-s", "emulator-5554"])
        self.assertTrue(result["passed"])
        self.assertEqual([s["pids"] for s in result["samples"]], [["4026"], ["4026"], []])
        self.assertEqual(sum(r["label"] == "stop-app-before-onboarding-reset" for r in commands.records), 1)

    def test_onboarding_stop_rejects_persistent_process_with_bounded_failed_receipt(self):
        class FakeCommands:
            evidence = self.root
            records = []

            def run(self, label, argv, **kwargs):
                self.records.append({"label": label, "exitCode": 0})
                return "4026" if "pidof" in argv else ""

        with patch.object(gate.time, "monotonic", side_effect=[0, 0, 1, 11]), \
                patch.object(gate.time, "sleep"):
            with self.assertRaisesRegex(RuntimeError, "App remained running"):
                gate.stop_owned_app_for_onboarding(FakeCommands(), ["fake-adb", "-s", "emulator-5554"])
        self.assertFalse(json.loads((self.root / "onboarding-app-stop-result.json").read_text())["passed"])

    def test_onboarding_stop_does_not_mistake_adb_failure_for_process_exit(self):
        class FakeCommands:
            evidence = self.root
            records = []

            def run(self, label, argv, **kwargs):
                self.records.append({"label": label, "exitCode": 1})
                return "error: device offline" if "pidof" in argv else ""

        with self.assertRaisesRegex(RuntimeError, "invalid pidof result"):
            gate.stop_owned_app_for_onboarding(FakeCommands(), ["fake-adb", "-s", "emulator-5554"])
        self.assertFalse(json.loads((self.root / "onboarding-app-stop-result.json").read_text())["passed"])

    def test_onboarding_stop_rejects_unowned_phone(self):
        with self.assertRaisesRegex(RuntimeError, "owned emulator"):
            gate.stop_owned_app_for_onboarding(None, ["adb", "-s", "owner-phone"])

    def test_maestro_nonzero_exit_cannot_pass_via_a_successful_junit_file(self):
        flow = self.root / ".maestro/flows/03-onboarding-tutorial.yaml"
        flow.parent.mkdir(parents=True)
        flow.write_text("# synthetic source marker; fake commands never execute the flow")

        class FakeCommands:
            def __init__(self, evidence):
                self.evidence = evidence
                self.records = []

            def run(self, label, argv, **kwargs):
                failed_maestro = label == "standalone-onboarding-maestro"
                self.records.append({"label": label, "exitCode": 1 if failed_maestro else 0, "timedOut": False})
                if failed_maestro:
                    Path(argv[argv.index("--output") + 1]).write_text('<testsuite tests="1"><testcase name="03-onboarding-tutorial"/></testsuite>')
                return "2.10.0" if label == "onboarding-maestro-version" else ""

        with patch.object(gate.shutil, "which", return_value="fake-maestro"):
            with self.assertRaisesRegex(RuntimeError, "Maestro command failed"):
                gate.standalone_onboarding(FakeCommands(self.root), self.root,
                                           ["fake-adb", "-s", "emulator-5554"])
        receipt = json.loads((self.root / "standalone-onboarding-result.json").read_text())
        self.assertFalse(receipt["passed"])
        self.assertEqual(receipt["originalMaestroExitCode"], 1)

    def test_maestro_os_launch_failure_preserves_original_failed_receipt(self):
        flow = self.root / ".maestro/flows/03-onboarding-tutorial.yaml"
        flow.parent.mkdir(parents=True)
        flow.write_text("# synthetic source; no tool or device is actually launched")
        evidence = self.root / "evidence"

        def fake_process(argv, **kwargs):
            if argv[0] == "fake-maestro" and "test" in argv:
                raise FileNotFoundError("synthetic missing CLI")
            return subprocess.CompletedProcess(argv, 0, "2.10.0" if "--version" in argv else "")

        with patch.object(gate.shutil, "which", return_value="fake-maestro"), \
                patch.object(gate.subprocess, "run", side_effect=fake_process):
            with self.assertRaisesRegex(RuntimeError, "could not be launched"):
                gate.standalone_onboarding(gate.Commands(evidence), self.root,
                                           ["fake-adb", "-s", "emulator-5554"])
        receipt = json.loads((evidence / "standalone-onboarding-result.json").read_text())
        self.assertFalse(receipt["passed"])
        self.assertIsNone(receipt["originalMaestroExitCode"])
        self.assertTrue(receipt["maestroLaunchFailed"])

    def test_onboarding_stops_before_log_window_and_rejects_any_later_process_death(self):
        flow = self.root / ".maestro/flows/03-onboarding-tutorial.yaml"
        flow.parent.mkdir(parents=True)
        flow.write_text("# synthetic source; no device is actually used")

        class FakeCommands:
            def __init__(self, evidence):
                self.evidence = evidence
                self.records = []

            def run(self, label, argv, **kwargs):
                self.records.append({"label": label, "exitCode": 0, "timedOut": False})
                if label == "standalone-onboarding-maestro":
                    Path(argv[argv.index("--output") + 1]).write_text(
                        '<testsuite tests="1"><testcase name="03-onboarding-tutorial" status="SUCCESS"/></testsuite>')
                if label == "onboarding-flow-logcat":
                    return f"ActivityManager: Process {gate.PACKAGE} has died"
                return "2.10.0" if label == "onboarding-maestro-version" else ""

        commands = FakeCommands(self.root)
        with patch.object(gate.shutil, "which", return_value="fake-maestro"):
            with self.assertRaisesRegex(RuntimeError, "Crash/ANR/Flutter error"):
                gate.standalone_onboarding(commands, self.root, ["fake-adb", "-s", "emulator-5554"])
        labels = [record["label"] for record in commands.records]
        self.assertLess(labels.index("stop-app-before-onboarding-reset"), labels.index("clear-onboarding-flow-log"))
        self.assertLess(labels.index("verify-app-stopped-before-onboarding-reset"), labels.index("clear-onboarding-flow-log"))
        receipt = json.loads((self.root / "standalone-onboarding-result.json").read_text())
        self.assertFalse(receipt["passed"])
        self.assertEqual(len(receipt["duringFlowFatalScan"]["failures"]), 1)


if __name__ == "__main__":
    unittest.main()
