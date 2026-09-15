import unittest
from pathlib import Path
from tempfile import TemporaryDirectory

from run_16k_adb_smoke import (
    app_fatals,
    app_ui_marker,
    focused_window,
    is_chronospark_activity,
    resumed_activity,
    source_version_code,
)


class ForegroundAttributionTests(unittest.TestCase):
    def test_installed_version_is_bound_to_matching_source_guards(self):
        with TemporaryDirectory() as folder:
            pubspec = Path(folder) / "pubspec.yaml"
            gradle = Path(folder) / "gradle.properties"
            pubspec.write_text("version: 4.1.0+2026083054\n")
            gradle.write_text("CHRONOSPARK_VERSION_CODE=2026083054\n")
            self.assertEqual(source_version_code(pubspec, gradle), "2026083054")
            gradle.write_text("CHRONOSPARK_VERSION_CODE=2026083053\n")
            with self.assertRaises(AssertionError):
                source_version_code(pubspec, gradle)

    def test_app_owned_ready_marker_excludes_loading_spinner(self):
        ready = b'<hierarchy><node package="com.ghostheart5.chronospark" content-desc="ENTER SYSTEM"/></hierarchy>'
        spinner = b'<hierarchy><node package="com.ghostheart5.chronospark" content-desc="Loading"/></hierarchy>'
        self.assertEqual(app_ui_marker(ready), ("ENTER SYSTEM", 1))
        self.assertEqual(app_ui_marker(spinner), ("", 1))
        self.assertEqual(app_ui_marker(b"<hierarchy><node"), ("", 0))

    def test_other_package_and_substring_cannot_supply_ui_readiness(self):
        xml = b'''<hierarchy>
          <node package="com.android.launcher" content-desc="NEXUS"/>
          <node package="com.ghostheart5.chronospark" content-desc="NEXUSLIKE"/>
        </hierarchy>'''
        self.assertEqual(app_ui_marker(xml), ("", 1))

    def test_input_focus_and_resumed_activity_identify_the_app(self):
        input_dump = """  FocusedApplications:
    displayId=0, name='ActivityRecord{42 u0 com.ghostheart5.chronospark/.MainActivity}'
  FocusedWindows:
    displayId=0, name='7d1eca com.ghostheart5.chronospark/com.ghostheart5.chronospark.MainActivity'
  FocusRequests:
    displayId=0, name='old com.android.launcher/com.android.launcher.Home' result='OK'
"""
        activity_dump = """topResumedActivity=ActivityRecord{42 u0 com.ghostheart5.chronospark/.MainActivity}
ResumedActivity: ActivityRecord{42 u0 com.ghostheart5.chronospark/.MainActivity}
"""
        self.assertTrue(is_chronospark_activity(focused_window(input_dump)))
        self.assertTrue(is_chronospark_activity(resumed_activity(activity_dump)))

    def test_stale_app_window_does_not_override_launcher_focus(self):
        input_dump = """  FocusedWindows:
    displayId=0, name='home com.android.launcher/com.android.launcher.Home'
  FocusRequests:
    displayId=0, name='old com.ghostheart5.chronospark/.MainActivity' result='OK'
"""
        activity_dump = """topResumedActivity=ActivityRecord{44 u0 com.android.launcher/.Home}
Activities=[ActivityRecord{42 u0 com.ghostheart5.chronospark/.MainActivity}]
"""
        self.assertFalse(is_chronospark_activity(focused_window(input_dump)))
        self.assertFalse(is_chronospark_activity(resumed_activity(activity_dump)))

    def test_conflicting_display_zero_focus_fails_closed(self):
        input_dump = """  FocusedWindows:
    displayId=0, name='first com.ghostheart5.chronospark/.MainActivity'
    displayId=0, name='second com.android.launcher/.Home'
  FocusRequests:
"""
        self.assertEqual(focused_window(input_dump), "")


class AppFatalAttributionTests(unittest.TestCase):
    def test_maestro_agent_crash_is_not_an_app_crash(self):
        log = "\n".join(
            [
                "F libc: Fatal signal 11 in pid 5437",
                "F DEBUG: Cmdline: dev.mobile.maestro",
                "F DEBUG: >>> dev.mobile.maestro <<<",
                "I ActivityManager: Process com.ghostheart5.chronospark foreground",
            ]
        )
        self.assertEqual(app_fatals(log), [])

    def test_app_java_fatal_is_attributed(self):
        log = "\n".join(
            [
                "E AndroidRuntime: FATAL EXCEPTION: main",
                "E AndroidRuntime: Process: com.ghostheart5.chronospark, PID: 5612",
            ]
        )
        self.assertEqual(len(app_fatals(log)), 1)

    def test_app_native_fatal_is_attributed(self):
        log = "\n".join(
            [
                "F libc: Fatal signal 11 in pid 5612",
                "F DEBUG: Cmdline: com.ghostheart5.chronospark",
                "F DEBUG: >>> com.ghostheart5.chronospark <<<",
            ]
        )
        self.assertEqual(len(app_fatals(log)), 1)


if __name__ == "__main__":
    unittest.main()
