"""Integrity and exact-edit regressions for passive emulator startup."""
import hashlib
from pathlib import Path
import unittest
from unittest.mock import patch

import prepare_hosted_emulator_runner as runner


class PassiveStartupTest(unittest.TestCase):
    def recipe(self, original, patched):
        return patch.multiple(runner,
                              ORIGINAL_SHA256=hashlib.sha256(original).hexdigest(),
                              PATCHED_SHA256=hashlib.sha256(patched).hexdigest())

    def test_only_menu_line_changes(self):
        original = b'await waitForDevice(port, timeout);\n' + runner.MENU + b'keepEveryOtherByte();\n'
        expected = original.replace(runner.MENU, runner.PASSIVE)
        with self.recipe(original, expected):
            actual = runner.patch_module(original)
        self.assertEqual(actual, expected)
        self.assertEqual(actual.replace(runner.PASSIVE, runner.MENU), original)
        self.assertNotIn(b'input keyevent', actual)

    def test_unreviewed_input_hash_is_rejected(self):
        with self.assertRaises(ValueError): runner.patch_module(runner.MENU)

    def test_missing_menu_is_rejected_even_if_input_hash_matches(self):
        original = b'no menu input\n'
        with self.recipe(original, original):
            with self.assertRaises(ValueError): runner.patch_module(original)

    def test_duplicate_menu_is_rejected_even_if_input_hash_matches(self):
        original = runner.MENU * 2
        with self.recipe(original, runner.PASSIVE * 2):
            with self.assertRaises(ValueError): runner.patch_module(original)

    def test_unexpected_output_hash_is_rejected(self):
        with self.recipe(runner.MENU, b'wrong output'):
            with self.assertRaises(ValueError): runner.patch_module(runner.MENU)

    def test_workstation_execution_is_rejected_before_mutation(self):
        with patch.dict(runner.os.environ, {}, clear=True):
            with self.assertRaises(ValueError): runner.prepare(Path.cwd())


if __name__ == '__main__':
    unittest.main()
