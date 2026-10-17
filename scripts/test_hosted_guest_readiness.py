"""Exercise the hosted readiness script with synthetic ADB responses, no device."""
import json
import os
from pathlib import Path
import sys
import tempfile
import types
import unittest
from unittest.mock import patch

WORKFLOW = Path(__file__).resolve().parents[1] / '.github/workflows/maestro-runtime.yml'
TEXT = WORKFLOW.read_text(encoding='utf-8')
BLOCK = TEXT.split("cat > test-results/maestro-prewarm/prepare_guest.py <<'PY'\n", 1)[1].split('\n          PY', 1)[0]
CODE = compile('\n'.join(line[10:] for line in BLOCK.splitlines()), str(WORKFLOW), 'exec')
HOME = 'com.google.android.apps.nexuslauncher/.NexusLauncherActivity'
SETUP = 'com.google.android.googlesdksetup/.DefaultActivity'
FIXTURE = json.loads((Path(__file__).parent / 'fixtures/hosted_guest_api35.json').read_text(encoding='utf-8'))


class GuestReadinessTest(unittest.TestCase):
    def execute(self, *, anr_at=None, anr_package='com.google.android.apps.nexuslauncher', focus=None, resumed=None, dialog=False, home=HOME, homes=None, activities=None, task_type='home', task_user='0', task_visible='true', pages='4096', qemu='1', user='0', expected_error=None):
        samples = [True] * 7 if focus is None else focus
        resumed_samples = samples if resumed is None else resumed
        home_samples = [HOME] * 7 if homes is None else homes
        index = -1
        def adb(command, timeout):
            nonlocal index
            self.assertEqual(command[:4], ['adb', '-s', 'emulator-5554', 'shell'])
            self.assertEqual(timeout, 20)
            args = command[4:]
            if args == ['getprop', 'ro.kernel.qemu']: value = qemu
            elif args == ['am', 'get-current-user']: value = user
            elif args == ['getconf', 'PAGE_SIZE']: value = pages
            elif args == ['getprop', 'ro.build.version.sdk']: value = '35'
            elif args == ['cat', '/sys/devices/system/cpu/present']: value = '0-3'
            elif args[:3] == ['cmd', 'package', 'resolve-activity']: value = home
            elif args == ['getprop', 'sys.boot_completed']:
                index += 1
                value = '1'
            elif args == ['pm', 'path', 'android']: value = 'package:/system/framework/framework-res.apk'
            elif args == ['dumpsys', 'window', 'windows']:
                value = FIXTURE['windowWindows']
                if dialog: value += '\nApplication Not Responding'
            elif args == ['dumpsys', 'activity', 'activities']:
                component = home_samples[index]
                package, activity = component.split('/')
                expanded = package + '/' + (package + activity if activity.startswith('.') else activity)
                value = ('* Task{abc #7 type=' + task_type + ' I=' + component + ' U=' + task_user + ' visible=' + task_visible + ' visibleRequested=true}\n'
                         + ('ResumedActivity: ActivityRecord{abc u0 ' + component + ' t7}' if resumed_samples[index] else 'ResumedActivity: null') + '\n'
                         + ('mCurrentFocus=Window{abc u0 ' + expanded + '}' if samples[index] else 'mCurrentFocus=null'))
                if activities is not None: value = activities[index]
            elif args == ['dumpsys', 'activity', 'lastanr']:
                if anr_at != index:
                    value = '<no anr has occurred since boot>'
                elif anr_package is None:
                    value = 'Unexpected activity manager diagnostics'
                else:
                    value = 'ANR in ' + anr_package
            elif args == ['cat', '/proc/meminfo']: value = 'MemAvailable: 2000000 kB'
            else: self.fail('Unexpected ADB command: ' + repr(args))
            return value.encode()
        fake_os = types.SimpleNamespace(name='posix', environ={'GITHUB_ACTIONS': 'true', 'QA_GUEST_PAGES': '4k'}, cpu_count=lambda: 4)
        original_read = Path.read_text
        def read(path, *args, **kwargs):
            if path.as_posix() == '/proc/meminfo': return 'MemAvailable: 10000000 kB'
            if path.as_posix() == '/proc/loadavg': return '1.0 1.0 1.0'
            return original_read(path, *args, **kwargs)
        with tempfile.TemporaryDirectory() as temp:
            previous = Path.cwd()
            try:
                os.chdir(temp)
                root = Path('test-results/maestro-prewarm')
                root.mkdir(parents=True)
                with patch.dict(sys.modules, {'os': fake_os}), patch('subprocess.check_output', side_effect=adb), patch('time.sleep'), patch.object(Path, 'read_text', read):
                    if expected_error is not None:
                        with self.assertRaisesRegex(AssertionError, expected_error): exec(CODE, {})
                    else: exec(CODE, {})
                receipt = root / 'guest-readiness.json'
                return json.loads(receipt.read_text()) if receipt.exists() else None
            finally: os.chdir(previous)

    def test_stable_launcher_has_seven_samples_and_no_application_tests(self):
        receipt = self.execute()
        self.assertTrue(receipt['passed'])
        self.assertEqual(len(receipt['samples']), 7)
        self.assertEqual(receipt['applicationTestsExecuted'], 0)
        self.assertEqual(receipt['guestCpuPresent'], '0-3')

    def test_system_anr_does_not_fail_guest_readiness(self):
        self.assertTrue(self.execute(anr_at=0)['passed'])

    def test_first_sample_app_anr_fails_and_retains_receipt(self):
        receipt = self.execute(anr_at=0, anr_package='com.ghostheart5.chronospark.qa',
                               expected_error='ANR in the app before app tests')
        self.assertFalse(receipt['passed'])

    def test_app_process_anr_fails(self):
        self.assertFalse(self.execute(anr_at=0, anr_package='com.ghostheart5.chronospark.qa:remote',
                                      expected_error='ANR in the app before app tests')['passed'])

    def test_late_app_anr_cannot_be_hidden_by_earlier_readiness(self):
        receipt = self.execute(anr_at=6, anr_package='com.ghostheart5.chronospark.qa',
                               expected_error='ANR in the app before app tests')
        self.assertFalse(receipt['passed'])

    def test_unknown_anr_output_fails_closed(self):
        receipt = self.execute(anr_at=0, anr_package=None,
                               expected_error='Unable to determine fresh guest ANR state')
        self.assertFalse(receipt['passed'])

    def test_error_dialog_fails(self):
        self.assertFalse(self.execute(dialog=True, expected_error='')['passed'])

    def test_boot_completed_without_home_focus_fails(self):
        self.assertFalse(self.execute(focus=[False]*7, expected_error='stable focused/resumed')['passed'])

    def test_focus_without_resumed_activity_fails(self):
        self.assertFalse(self.execute(resumed=[False]*7, expected_error='stable focused/resumed')['passed'])

    def test_resumed_activity_without_focus_fails(self):
        self.assertFalse(self.execute(focus=[False]*7, resumed=[True]*7, expected_error='stable focused/resumed')['passed'])

    def test_recent_focus_loss_resets_stability(self):
        self.assertFalse(self.execute(focus=[True]*5+[False,True], expected_error='stable focused/resumed')['passed'])

    def test_delayed_home_focus_can_settle_within_same_window(self):
        self.assertTrue(self.execute(focus=[False]*4+[True]*3)['passed'])

    def test_actual_api35_snapshot_with_setup_resolver(self):
        receipt = self.execute(home=FIXTURE['resolvedHomeBeforeSettling'], activities=[FIXTURE['activities']]*7)
        self.assertTrue(receipt['passed'])
        self.assertEqual(receipt['homeActivity'], HOME)
        self.assertEqual(receipt['resolvedHomeBeforeSettling'], SETUP)

    def test_setup_to_launcher_transition_resets_stability(self):
        receipt = self.execute(home=SETUP, homes=[SETUP]*4+[HOME]*3)
        self.assertTrue(receipt['passed'])
        self.assertEqual([s['stableHomeSamples'] for s in receipt['samples']], [0,0,0,0,1,2,3])

    def test_setup_activity_alone_does_not_certify_launcher_readiness(self):
        self.assertFalse(self.execute(home=SETUP, homes=[SETUP]*7, expected_error='stable focused/resumed')['passed'])

    def test_home_transition_needs_three_same_activity_samples(self):
        self.assertFalse(self.execute(home=SETUP, homes=[SETUP]*5+[HOME]*2, expected_error='stable focused/resumed')['passed'])

    def test_unresolved_early_resolver_does_not_override_visible_home_task(self):
        self.assertTrue(self.execute(home='No activity found')['passed'])

    def test_non_home_foreground_task_cannot_certify_readiness(self):
        self.assertFalse(self.execute(task_type='standard', expected_error='stable focused/resumed')['passed'])

    def test_hidden_home_task_cannot_certify_readiness(self):
        self.assertFalse(self.execute(task_visible='false', expected_error='stable focused/resumed')['passed'])

    def test_other_user_home_task_cannot_certify_readiness(self):
        self.assertFalse(self.execute(task_user='11', expected_error='stable focused/resumed')['passed'])

    def test_same_package_wrong_activity_cannot_certify_readiness(self):
        wrong = FIXTURE['activities'].replace('mCurrentFocus=Window{abc u0 com.google.android.apps.nexuslauncher/com.google.android.apps.nexuslauncher.NexusLauncherActivity}', 'mCurrentFocus=Window{abc u0 com.google.android.apps.nexuslauncher/com.google.android.apps.nexuslauncher.OtherActivity}')
        self.assertFalse(self.execute(activities=[wrong]*7, expected_error='stable focused/resumed')['passed'])

    def test_ambiguous_visible_home_tasks_cannot_certify_readiness(self):
        ambiguous = FIXTURE['activities'] + '* Task{aaa #8 type=home I=' + SETUP + ' U=0 visible=true}\n'
        self.assertFalse(self.execute(activities=[ambiguous]*7, expected_error='stable focused/resumed')['passed'])

    def test_wrong_page_size_is_rejected(self):
        self.assertIsNone(self.execute(pages='16384', expected_error='page size'))

    def test_physical_device_is_rejected(self):
        self.assertIsNone(self.execute(qemu='0', expected_error='owned hosted emulator'))

    def test_wrong_android_user_is_rejected(self):
        self.assertIsNone(self.execute(user='11', expected_error='.*'))


if __name__ == '__main__': unittest.main()
