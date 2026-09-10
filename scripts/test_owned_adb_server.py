"""Ownership and failure contracts; no Android SDK or emulator required."""
import os
from pathlib import Path
import socket
import subprocess
import tempfile
import unittest
from unittest.mock import patch

from owned_adb_server import OwnedAdbServer


class Process:
    pid = 12345
    returncode = None
    def poll(self): return self.returncode
    def terminate(self): self.returncode = -15
    def kill(self): self.returncode = -9
    def wait(self, timeout): return self.returncode


class OwnedAdbTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)

    def port(self):
        with socket.socket() as probe:
            probe.bind(('127.0.0.1', 0))
            return probe.getsockname()[1]

    def test_default_privileged_and_invalid_ports_are_refused(self):
        for port in (5037, 0, 1023, 65536, '55001', True):
            with self.subTest(port=port), self.assertRaises(ValueError):
                OwnedAdbServer('adb', self.root, port)

    def test_busy_port_is_not_adopted_or_terminated(self):
        with socket.socket() as other:
            other.bind(('127.0.0.1', 0))
            other.listen()
            owner = OwnedAdbServer('adb', self.root, other.getsockname()[1])
            before = dict(os.environ)
            with patch('owned_adb_server.subprocess.Popen') as start, self.assertRaises(OSError):
                owner.start()
            start.assert_not_called()
            self.assertEqual(dict(os.environ), before)
            self.assertTrue(owner.listening())

    def test_foreground_server_uses_nondefault_port_and_restores_environment(self):
        owner = OwnedAdbServer('sdk/adb', self.root, self.port())
        process = Process()
        with patch.dict(os.environ, {'ANDROID_ADB_SERVER_PORT': '5037', 'ADB_SERVER_SOCKET': 'tcp:old:5037'}):
            before = dict(os.environ)
            with patch.object(owner, 'listening', side_effect=[False, True, False]), \
                    patch('owned_adb_server.subprocess.Popen', return_value=process) as start:
                owner.start()
                argv = start.call_args.args[0]
                self.assertEqual(argv, ['sdk/adb', '-L', f'tcp:{owner.port}', '--one-device',
                                        'CHRONOSPARK_NO_USB', 'server', 'nodaemon'])
                self.assertNotIn('-a', argv)
                self.assertEqual(os.environ['ANDROID_ADB_SERVER_PORT'], str(owner.port))
                self.assertEqual(os.environ['ADB_MDNS_AUTO_CONNECT'], '0')
                self.assertEqual(start.call_args.kwargs['env']['ADB_TRACE'], 'transport,sockets,services')
                owner.assert_alive()
                owner.stop()
            self.assertEqual(dict(os.environ), before)
        self.assertTrue(owner.receipt['stopped'])
        self.assertFalse(owner.receipt['unexpectedServerExit'])
        self.assertEqual(process.returncode, -15)

    def test_early_exit_is_not_masked_by_a_replacement_listener(self):
        owner = OwnedAdbServer('adb', self.root, self.port())
        process = Process()
        with patch.object(owner, 'listening', side_effect=[False, True, True]), \
                patch('owned_adb_server.subprocess.Popen', return_value=process):
            owner.start()
            process.returncode = 1
            with self.assertRaisesRegex(RuntimeError, 'auto-restart'):
                owner.assert_alive()
            owner.stop()
        self.assertTrue(owner.receipt['unexpectedServerExit'])
        self.assertFalse(owner.receipt['stopped'])

    def test_launch_error_restores_environment_without_stopping_other_processes(self):
        owner = OwnedAdbServer('missing-adb', self.root, self.port())
        before = dict(os.environ)
        with patch.object(owner, 'listening', return_value=False), \
                patch('owned_adb_server.subprocess.Popen', side_effect=OSError('missing')):
            with self.assertRaises(OSError): owner.start()
        self.assertEqual(dict(os.environ), before)
        self.assertFalse(owner.receipt['started'])
        self.assertTrue(owner.receipt['stopped'])

    def test_stop_escalates_only_the_process_it_created(self):
        owner = OwnedAdbServer('adb', self.root, self.port())
        process = Process()
        with patch.object(owner, 'listening', side_effect=[False, True, False]), \
                patch('owned_adb_server.subprocess.Popen', return_value=process), \
                patch.object(process, 'wait', side_effect=[subprocess.TimeoutExpired('adb', 10), -9]):
            owner.start()
            owner.stop()
        self.assertTrue(owner.receipt['stopped'])
        self.assertEqual(process.returncode, -9)


if __name__ == '__main__': unittest.main()
