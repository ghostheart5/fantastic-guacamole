"""Exercise the exact workflow image selection/provenance code without a device."""
import hashlib
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

TEXT = (Path(__file__).resolve().parents[1] / '.github/workflows/maestro-runtime.yml').read_text()


def block(start, end):
    body = TEXT.split(start + '\n', 1)[1].split('\n          ' + end, 1)[0]
    return compile('\n'.join(line[10:] for line in body.splitlines()), '<workflow image code>', 'exec')


SELECT = block("python3 - <<'GUEST_IMAGE_SELECTION'", 'GUEST_IMAGE_SELECTION')
RECORD = block("cat > test-results/maestro-prewarm/record_guest_image.py <<'GUEST_IMAGE_RECORD'", 'GUEST_IMAGE_RECORD')


class HostedGuestImageTest(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.base = Path(temporary.name)
        previous = Path.cwd()
        os.chdir(self.base)
        self.addCleanup(os.chdir, previous)
        self.root = self.base / 'test-results/maestro-prewarm'
        self.root.mkdir(parents=True)
        self.sdk = self.base / 'sdk'
        self.avd = self.base / 'avd/test.avd'
        self.avd.mkdir(parents=True)
        self.env = {'QA_SUITE': 'qa-smoke', 'QA_GUEST_API': '35', 'QA_GUEST_PAGES': '4k',
                    'QA_MONKEY': 'false', 'QA_MONKEY_ONLY': 'false', 'QA_SOURCE_SHA': 'a' * 40,
                    'GITHUB_RUN_ID': '12345', 'GITHUB_RUN_ATTEMPT': '1',
                    'GITHUB_OUTPUT': str(self.base / 'output.txt'), 'ANDROID_HOME': str(self.sdk),
                    'ANDROID_AVD_HOME': str(self.avd.parent)}

    def select(self, **changes):
        with patch.dict(os.environ, {**self.env, **changes}, clear=True):
            exec(SELECT, {})
        receipt = json.loads((self.root / 'image-selection.json').read_text())
        self.assertEqual((self.base / 'output.txt').read_text(), 'target=' + receipt['target'] + '\n')
        self.assertFalse(receipt['googleServicesIntegrationCovered'])
        return receipt

    def prepare_image(self, relative='system-images/android-35/default/x86_64', properties=b'Pkg.Desc=AOSP\nPkg.Revision=2\n'):
        self.select()
        image = self.sdk / relative
        image.mkdir(parents=True)
        (image / 'source.properties').write_bytes(properties)
        (self.avd / 'config.ini').write_text('AvdId=test\nimage.sysdir.1=' + relative + '/\n')
        return image

    def record(self, **changes):
        with patch.dict(os.environ, {**self.env, **changes}, clear=True):
            exec(RECORD, {})
        return json.loads((self.root / 'guest-image.json').read_text())

    def test_only_normal_api35_smoke_selects_aosp(self):
        self.assertEqual(self.select()['target'], 'default')

    def test_journeys_keep_google_services_image(self):
        self.assertEqual(self.select(QA_SUITE='qa-journeys')['target'], 'google_apis')

    def test_native16k_keeps_google_16k_image(self):
        self.assertEqual(self.select(QA_SUITE='qa-16k-native', QA_GUEST_PAGES='16k')['target'], 'google_apis_ps16k')

    def test_16k_pages_take_precedence_over_smoke_selection(self):
        self.assertEqual(self.select(QA_GUEST_PAGES='16k')['target'], 'google_apis_ps16k')

    def test_api36_smoke_keeps_google_services_image(self):
        self.assertEqual(self.select(QA_GUEST_API='36')['target'], 'google_apis')

    def test_monkey_keeps_google_services_image(self):
        self.assertEqual(self.select(QA_MONKEY='true')['target'], 'google_apis')

    def test_monkey_only_keeps_google_services_image(self):
        self.assertEqual(self.select(QA_MONKEY_ONLY='true')['target'], 'google_apis')

    def test_unknown_api_is_rejected(self):
        with self.assertRaises(AssertionError): self.select(QA_GUEST_API='34')

    def test_unknown_pages_are_rejected(self):
        with self.assertRaises(AssertionError): self.select(QA_GUEST_PAGES='64k')

    def test_unknown_suite_is_rejected(self):
        with self.assertRaises(AssertionError): self.select(QA_SUITE='anything')

    def test_non_boolean_monkey_flags_are_rejected(self):
        with self.assertRaises(AssertionError): self.select(QA_MONKEY='yes')

    def test_unbound_source_is_rejected(self):
        with self.assertRaises(AssertionError): self.select(QA_SOURCE_SHA='main')

    def test_actual_avd_image_and_properties_are_bound(self):
        image = self.prepare_image()
        result = self.record()
        self.assertTrue(result['actualAvdImageMatched'])
        self.assertEqual(Path(result['sdkImagePath']), image.resolve())
        self.assertEqual(result['sourcePropertiesSha256'], hashlib.sha256((image / 'source.properties').read_bytes()).hexdigest())
        self.assertEqual(result['avdConfigSha256'], hashlib.sha256((self.avd / 'config.ini').read_bytes()).hexdigest())

    def test_google_image_cannot_masquerade_as_aosp(self):
        self.prepare_image('system-images/android-35/google_apis/x86_64')
        with self.assertRaises(AssertionError): self.record()
        self.assertFalse((self.root / 'guest-image.json').exists())

    def test_wrong_abi_is_rejected(self):
        self.prepare_image('system-images/android-35/default/arm64-v8a')
        with self.assertRaises(AssertionError): self.record()

    def test_duplicate_image_paths_are_rejected(self):
        self.prepare_image()
        with (self.avd / 'config.ini').open('a') as f: f.write('image.sysdir.1=another-image/\n')
        with self.assertRaises(AssertionError): self.record()

    def test_image_outside_sdk_is_rejected(self):
        self.prepare_image()
        outside = self.base / 'outside'
        outside.mkdir()
        (outside / 'source.properties').write_text('Pkg.Revision=2\n')
        (self.avd / 'config.ini').write_text('image.sysdir.1=' + str(outside) + '\n')
        with self.assertRaises(AssertionError): self.record()

    def test_missing_source_properties_is_rejected(self):
        self.prepare_image()
        (self.sdk / 'system-images/android-35/default/x86_64/source.properties').unlink()
        with self.assertRaises(FileNotFoundError): self.record()

    def test_missing_revision_is_rejected(self):
        self.prepare_image(properties=b'Pkg.Desc=Unknown\n')
        with self.assertRaises(AssertionError): self.record()

    def test_different_source_is_rejected(self):
        self.prepare_image()
        with self.assertRaises(AssertionError): self.record(QA_SOURCE_SHA='b' * 40)

    def test_different_attempt_is_rejected(self):
        self.prepare_image()
        with self.assertRaises(AssertionError): self.record(GITHUB_RUN_ATTEMPT='2')


if __name__ == '__main__':
    unittest.main()
