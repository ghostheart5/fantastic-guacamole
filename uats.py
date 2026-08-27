#!/usr/bin/env python3
"""Compatibility entry point for the canonical non-build reliability gate.

The historical script generated stale JSON reports and checked retired routes.
Keep this filename for existing developer shortcuts, but delegate to the
maintained PowerShell gate so there is one source of truth.
"""

from __future__ import annotations

import shutil
import subprocess
import sys
from pathlib import Path


def main() -> int:
    root = Path(__file__).resolve().parent
    shell = shutil.which("pwsh") or shutil.which("powershell")
    if shell is None:
        print("PowerShell is required to run scripts/strict_gate.ps1", file=sys.stderr)
        return 2

    command = [
        shell,
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        str(root / "scripts" / "strict_gate.ps1"),
        "-IncludeCoverage",
    ]
    print("Running the canonical ChronoSpark non-build reliability gate...")
    return subprocess.run(command, cwd=root, check=False).returncode


if __name__ == "__main__":
    raise SystemExit(main())
