import unittest

from run_16k_adb_smoke import app_fatals


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
