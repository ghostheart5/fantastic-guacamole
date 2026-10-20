"""Bounded, fail-closed Flutter/Gradle diagnostics; raw output is never printed."""
import os
import re
import subprocess
import sys

MAX_INPUT_LINE_BYTES = 4096
MAX_OUTPUT_BYTES = 16384
MAX_OUTPUT_LINES = 96
_PREFIX = r"(?:java\.|javax\.|sun\.|org\.gradle\.|com\.android\.|com\.google\.|kotlin\.|groovy\.)"
_CLASS = _PREFIX + r"[A-Za-z0-9_.$]{1,180}"
_CAUSE = re.compile(r"^(?:Caused by: |Suppressed: )?(" + _CLASS + r")(?::|\s*$)")
_FRAME = re.compile(r"^\s*at (" + _CLASS + r")\((?:[A-Za-z0-9_$]{1,100}\.(?:java|kt|groovy):([0-9]{1,7})|Native Method|Unknown Source)\)\s*$")


class FailureDiagnostics:
    def __init__(self, environment):
        # Even allowed class/frame text is redacted before projection. No
        # arbitrary exception message, file path or process output is retained.
        sensitive = re.compile(r"SECRET|TOKEN|PASSWORD|KEY|ALIAS|CREDENTIAL|CHRONOSPARK|SUPABASE|GOOGLE")
        self._secrets = sorted({str(v) for k, v in environment.items()
                                if v and sensitive.search(k)}, key=len, reverse=True)
        self._pending = bytearray()
        self._discard = False
        self._lines = []
        self._bytes = 0

    def feed(self, chunk):
        for byte in chunk:
            if byte == 10:
                if not self._discard:
                    self._accept(bytes(self._pending))
                self._pending.clear()
                self._discard = False
            elif not self._discard:
                if len(self._pending) < MAX_INPUT_LINE_BYTES:
                    self._pending.append(byte)
                else:
                    self._pending.clear()
                    self._discard = True

    def finish(self):
        if self._pending and not self._discard:
            self._accept(bytes(self._pending))
        self._pending.clear()
        return tuple(self._lines)

    def _accept(self, raw):
        text = raw.decode("utf-8", errors="replace").rstrip("\r")
        for secret in self._secrets:
            text = text.replace(secret, "[redacted]")
        # Only project structured identifiers. Messages may contain passwords,
        # bearer values, source defines or aliases and are deliberately omitted.
        cause = _CAUSE.match(text)
        frame = _FRAME.fullmatch(text)
        if cause:
            line = "exception-class: " + cause[1]
        elif frame:
            line = "stack-frame: " + frame[1] + (":" + frame[2] if frame[2] else "")
        elif text == "Execution failed for task ':app:signReleaseBundle'.":
            line = "failed-task: :app:signReleaseBundle"
        else:
            return
        size = len((line + "\n").encode("utf-8"))
        # Reserve one line and 128 bytes for the fixed final status message.
        while self._lines and (len(self._lines) >= MAX_OUTPUT_LINES - 1 or
                               self._bytes + size > MAX_OUTPUT_BYTES - 128):
            # Prefer discarding old framework frames, retaining nested cause
            # classes that commonly appear late in a Gradle failure trace.
            index = next((i for i, old in enumerate(self._lines)
                          if old.startswith("stack-frame: ")), 0)
            self._bytes -= len((self._lines.pop(index) + "\n").encode("utf-8"))
        if size <= MAX_OUTPUT_BYTES - 128:
            self._lines.append(line)
            self._bytes += size


def run_flutter_release(args, cwd, environment=None, output=None):
    """Return the actual child exit code; do not retry or write raw log files."""
    environment = os.environ.copy() if environment is None else environment
    output = sys.stderr if output is None else output
    diagnostics = FailureDiagnostics(environment)
    with subprocess.Popen(args, cwd=cwd, env=environment, stdout=subprocess.PIPE,
                          stderr=subprocess.STDOUT) as process:
        while chunk := process.stdout.read(4096):
            diagnostics.feed(chunk)
        returncode = process.wait()
    lines = diagnostics.finish()
    if returncode:
        for line in lines:
            print(line, file=output)
        print("Flutter release failed; raw output suppressed.", file=output)
    else:
        print("Flutter release completed; artifact verification remains required.", file=output)
    return returncode
