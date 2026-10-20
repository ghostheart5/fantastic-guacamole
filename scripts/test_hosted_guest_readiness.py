"""Exercise the hosted readiness script with synthetic ADB responses, no device."""
import json
import os
from pathlib import Path
import sys
import tempfile
import types
import unittest
from unittest.mock import patch
from hosted_guest_anr import classify_anr

WORKFLOW = Path(__file__).resolve().parents[1] / '.github/workflows/maestro-runtime.yml'
TEXT = WORKFLOW.read_text(encoding='utf-8')
BLOCK = TEXT.split("cat > test-results/maestro-prewarm/prepare_guest.py <<'PY'\n", 1)[1].split('\n          PY', 1)[0]
CODE = compile('\n'.join(line[10:] for line in BLOCK.splitlines()), str(WORKFLOW), 'exec')
HOME = 'com.google.android.apps.nexuslauncher/.NexusLauncherActivity'
SETUP = 'com.google.android.googlesdksetup/.DefaultActivity'
FIXTURE = json.loads((Path(__file__).parent / 'fixtures/hosted_guest_api35.json').read_text(encoding='utf-8'))
ANR_FIXTURE = json.loads((Path(__file__).parent / 'fixtures/hosted_guest_api35_anr.json').read_text(encoding='utf-8'))


class GuestReadinessTest(unittest.TestCase):
    def execute(self, *, anr_at=None, anr_package='com.google.android.apps.nexuslauncher', focus=None, resumed=None, dialog=False, home=HOME, homes=None, activities=None, task_type='home', task_user='0', task_visible='true', pages='4096', qemu='1', user='0', expected_error=None, structured_anr=False):
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
                if structured_anr:
                    value = ANR_FIXTURE['lastAnr']
                elif anr_at != index:
                    value = '<no anr has occurred since boot>'
                elif anr_package is None:
                    value = 'Unexpected activity manager diagnostics'
                else:
                    value = 'ANR in ' + anr_package
            elif args == ['logcat', '-d', '-b', 'events', '-v', 'threadtime']:
                value = ANR_FIXTURE['events'] if structured_anr else ''
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

    def test_captured_activity_dump_records_system_anr_without_calling_it_clean(self):
        receipt = self.execute(structured_anr=True)
        self.assertTrue(receipt['passed'])
        self.assertTrue(all(sample['anrState']['systemAnrObserved'] for sample in receipt['samples']))
        self.assertFalse(receipt['lastAnrState']['appAnrObserved'])

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


class AnrClassificationTest(unittest.TestCase):
    APP = 'com.ghostheart5.chronospark.qa'

    def classify(self, last=None, events=None):
        return classify_anr(ANR_FIXTURE['lastAnr'] if last is None else last,
                            ANR_FIXTURE['events'] if events is None else events, self.APP)

    def test_actual_android35_event_correlates_with_dump(self):
        state = self.classify()
        self.assertEqual(state['lastAnrProcess'], 'com.google.android.apps.nexuslauncher')
        self.assertTrue(state['systemAnrObserved'])
        self.assertFalse(state['appAnrObserved'])

    def test_structured_app_anr_remains_an_app_failure(self):
        self.assertTrue(self.classify(events=ANR_FIXTURE['events'].replace('com.google.android.apps.nexuslauncher', self.APP))['appAnrObserved'])

    def test_remote_app_process_anr_is_not_mistaken_for_system(self):
        self.assertTrue(self.classify(events=ANR_FIXTURE['events'].replace('com.google.android.apps.nexuslauncher', self.APP + ':remote'))['appAnrObserved'])

    def test_similar_package_prefix_is_not_the_app_process(self):
        self.assertFalse(self.classify(events=ANR_FIXTURE['events'].replace('com.google.android.apps.nexuslauncher', self.APP + '.other'))['appAnrObserved'])

    def test_structured_dump_without_event_fails_closed(self):
        with self.assertRaisesRegex(ValueError, 'matched am_anr process'):
            self.classify(events='')

    def test_other_user_event_cannot_identify_current_user_dump(self):
        with self.assertRaisesRegex(ValueError, 'matched am_anr process'):
            self.classify(events=ANR_FIXTURE['events'].replace('[0,1240,', '[11,1240,'))

    def test_old_event_does_not_establish_current_anr_identity(self):
        with self.assertRaisesRegex(ValueError, 'matched am_anr process'):
            self.classify(events=ANR_FIXTURE['events'].replace('16:11:38.289', '16:10:38.289'))

    def test_different_reason_does_not_establish_anr_identity(self):
        with self.assertRaisesRegex(ValueError, 'matched am_anr process'):
            self.classify(events=ANR_FIXTURE['events'].replace('Application does not have a focused window', 'Different timeout'))

    def test_ambiguous_process_identity_fails_closed(self):
        events = ANR_FIXTURE['events'] + ANR_FIXTURE['events'].replace('com.google.android.apps.nexuslauncher', 'com.android.other')
        with self.assertRaisesRegex(ValueError, 'matched am_anr process'):
            self.classify(events=events)

    def test_malformed_event_cannot_be_silently_ignored(self):
        with self.assertRaisesRegex(ValueError, 'Malformed Android am_anr event'):
            self.classify(events=ANR_FIXTURE['events'].replace('[0,1240,', '[0,broken,'))

    def test_old_app_anr_cannot_be_hidden_by_later_launcher_anr(self):
        events = ANR_FIXTURE['events'].replace('16:11:38.289', '16:10:38.289').replace('com.google.android.apps.nexuslauncher', self.APP)
        events += ANR_FIXTURE['events']
        self.assertTrue(self.classify(events=events)['appAnrObserved'])

    def test_cleared_last_anr_does_not_hide_app_event(self):
        events = ANR_FIXTURE['events'].replace('com.google.android.apps.nexuslauncher', self.APP)
        self.assertTrue(self.classify(last='<no ANR has occurred since boot>', events=events)['appAnrObserved'])

    def test_clean_guest_requires_recognized_no_anr_evidence(self):
        self.assertFalse(self.classify(last='<no ANR has occurred since boot>', events='')['appAnrObserved'])
        with self.assertRaisesRegex(ValueError, 'Unrecognized Android lastanr evidence'):
            self.classify(last='Unexpected output', events='')

    def test_contradictory_no_anr_and_timestamp_is_rejected(self):
        with self.assertRaisesRegex(ValueError, 'Contradictory'):
            self.classify(last='<no ANR has occurred since boot>\n' + ANR_FIXTURE['lastAnr'])

    def test_final_guard_uses_same_parser_and_still_fails_app_anr(self):
        block = TEXT.split("python3 - test-results/maestro-prewarm/final-lastanr.txt <<'PY' || result=1\n", 1)[1].split('\n          PY', 1)[0]
        code = compile('\n'.join(line[10:] for line in block.splitlines()), str(WORKFLOW), 'exec')
        for app in (False, True, None):
            with tempfile.TemporaryDirectory() as temp:
                previous = Path.cwd()
                try:
                    os.chdir(temp)
                    root = Path('test-results/maestro-prewarm'); root.mkdir(parents=True)
                    dump = root / 'final-lastanr.txt'; dump.write_text(ANR_FIXTURE['lastAnr'])
                    events = ANR_FIXTURE['events']
                    if app: events = events.replace('com.google.android.apps.nexuslauncher', self.APP)
                    if app is None: events = ''
                    (root / 'system-logcat.txt').write_text(events)
                    with patch.object(sys, 'argv', ['-', str(dump)]):
                        if app is None:
                            with self.assertRaisesRegex(SystemExit, 'Unable to determine final guest ANR state'):
                                exec(code, {})
                        elif app:
                            with self.assertRaisesRegex(SystemExit, 'Final guest reported an ANR in the app'):
                                exec(code, {})
                        else:
                            exec(code, {})
                    result = json.loads((root / 'final-anr-state.json').read_text())
                    if app is None:
                        self.assertFalse(result['determined'])
                    else:
                        self.assertEqual(result['appAnrObserved'], app)
                        self.assertEqual(result['systemAnrObserved'], not app)
                finally:
                    os.chdir(previous)


if __name__ == '__main__': unittest.main()
