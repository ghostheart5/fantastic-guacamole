"""An invocation-owned loopback ADB server, separate from the user's/default server."""
import json
import os
from pathlib import Path
import socket
import subprocess
import time


class OwnedAdbServer:
    def __init__(self, executable, evidence, port):
        if type(port) is not int or not 1024 <= port <= 65535 or port == 5037:
            raise ValueError("A non-default unprivileged ADB server port is required")
        self.executable = str(executable)
        self.evidence = Path(evidence)
        self.port = port
        self.process = None
        self.stream = None
        self.previous = {}
        self.environment = {
            "ADB_SERVER_SOCKET": f"tcp:127.0.0.1:{port}",
            "ANDROID_ADB_SERVER_ADDRESS": "127.0.0.1",
            "ANDROID_ADB_SERVER_PORT": str(port),
            "ADB_MDNS_AUTO_CONNECT": "0",
        }
        self.receipt = {"started": False, "stopped": True, "port": port,
                        "defaultServerTouched": False, "unexpectedServerExit": False}

    def listening(self):
        with socket.socket() as client:
            client.settimeout(0.25)
            return client.connect_ex(("127.0.0.1", self.port)) == 0

    def save(self):
        self.evidence.mkdir(parents=True, exist_ok=True)
        (self.evidence / "owned-adb-server.json").write_text(
            json.dumps(self.receipt, indent=2) + "\n", encoding="utf-8")

    def start(self):
        # Never adopt or terminate a server already listening on this port.
        with socket.socket() as probe:
            probe.bind(("127.0.0.1", self.port))
        if self.listening():
            raise RuntimeError("Requested ADB server port is already in use")
        self.previous = {key: os.environ.get(key) for key in self.environment}
        os.environ.update(self.environment)
        server_env = dict(os.environ, ADB_TRACE="transport,sockets,services")
        # The Windows native backend cannot bind a named host in -L. Without
        # -a, tcp:PORT binds loopback; clients still connect to explicit 127.0.0.1.
        argv = [self.executable, "-L", f"tcp:{self.port}",
                "--one-device", "CHRONOSPARK_NO_USB", "server", "nodaemon"]
        self.evidence.mkdir(parents=True, exist_ok=True)
        self.stream = (self.evidence / "owned-adb-server.log").open("wb")
        try:
            self.process = subprocess.Popen(argv, stdout=self.stream, stderr=subprocess.STDOUT,
                                            env=server_env, stdin=subprocess.DEVNULL)
            self.receipt.update(started=True, stopped=False, pid=self.process.pid, argv=argv,
                                environment=self.environment)
            deadline = time.monotonic() + 15
            while not self.listening():
                self.assert_alive()
                if time.monotonic() >= deadline:
                    raise RuntimeError("Owned ADB server did not open its loopback port")
                time.sleep(0.1)
            self.assert_alive()
            self.save()
            return self
        except BaseException:
            self.stop()
            raise

    def assert_alive(self):
        if self.process is None or self.process.poll() is not None:
            self.receipt["unexpectedServerExit"] = True
            self.save()
            raise RuntimeError("Owned ADB server exited; client auto-restart must not count as continuity")

    def stop(self):
        try:
            if self.process is not None:
                if self.process.poll() is not None:
                    self.receipt["unexpectedServerExit"] = True
                else:
                    self.process.terminate()
                    try:
                        self.process.wait(timeout=10)
                    except subprocess.TimeoutExpired:
                        self.process.kill()
                        self.process.wait(timeout=5)
                self.receipt["exitCode"] = self.process.returncode
                self.receipt["stopped"] = self.process.poll() is not None and not self.listening()
        finally:
            if self.stream is not None:
                self.stream.close()
            for key, value in self.previous.items():
                if value is None:
                    os.environ.pop(key, None)
                else:
                    os.environ[key] = value
            self.save()
