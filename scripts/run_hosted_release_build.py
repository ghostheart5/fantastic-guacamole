"""Run only the hosted release build with an isolated, budgeted Gradle home."""
import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import subprocess
import sys
import tempfile

GIB = 1024 ** 3
HEAP_BYTES = 4 * GIB
METASPACE_BYTES = 512 * 1024 ** 2
CODE_CACHE_BYTES = 256 * 1024 ** 2
HEADROOM_BYTES = 2 * GIB
REQUIRED_BYTES = HEAP_BYTES + METASPACE_BYTES + CODE_CACHE_BYTES + HEADROOM_BYTES
PROPERTIES = (
    "org.gradle.jvmargs=-Xmx4g -XX:MaxMetaspaceSize=512m "
    "-XX:ReservedCodeCacheSize=256m -XX:-HeapDumpOnOutOfMemoryError\n"
    "org.gradle.workers.max=1\norg.gradle.parallel=false\n"
    "org.gradle.daemon=false\norg.gradle.configuration-cache=false\n"
)


def _mount_path(value):
    return re.sub(r"\\([0-7]{3})", lambda m: chr(int(m[1], 8)), value)


def _memory_hierarchy(proc):
    """Find this process's memory hierarchy, including its finite ancestors."""
    memberships = []
    for line in (proc / "self/cgroup").read_text().splitlines():
        _, controllers, group = line.split(":", 2)
        if not controllers or "memory" in controllers.split(","):
            memberships.append((not controllers, PurePosixPath(group)))
    if not memberships:
        return []
    mounts = []
    for line in (proc / "self/mountinfo").read_text().splitlines():
        before, after = line.split(" - ", 1)
        fields, fs = before.split(), after.split()
        if fs[0] == "cgroup2" or (fs[0] == "cgroup" and "memory" in fs[2].split(",")):
            mounts.append((fs[0] == "cgroup2", PurePosixPath(_mount_path(fields[3])),
                           Path(_mount_path(fields[4]))))
    for unified, group in memberships:
        if not group.is_absolute() or ".." in group.parts:
            raise RuntimeError("Unsafe cgroup membership path")
        for version2, mount_root, mount in mounts:
            if unified != version2 or not group.is_relative_to(mount_root):
                continue
            boundary = mount.resolve(strict=True)
            current = (boundary / str(group.relative_to(mount_root))).resolve(strict=True)
            if not current.is_relative_to(boundary):
                raise RuntimeError("Cgroup membership escapes its mount")
            levels = []
            while True:
                limit = current / ("memory.max" if version2 else "memory.limit_in_bytes")
                usage = current / ("memory.current" if version2 else "memory.usage_in_bytes")
                if limit.exists():
                    text = limit.read_text().strip()
                    if text == "max" and version2:
                        value = None
                    else:
                        value = int(text)
                        if value <= 0:
                            raise RuntimeError("Invalid cgroup memory limit")
                        # cgroup v1 uses a page-aligned LONG_MAX sentinel.
                        if not version2 and value >= 1 << 60:
                            value = None
                    used = int(usage.read_text().strip()) if value is not None else None
                    if used is not None and used < 0:
                        raise RuntimeError("Invalid cgroup memory usage")
                    levels.append({"version": 2 if version2 else 1,
                                   "limitBytes": value, "usageBytes": used})
                if current == boundary:
                    return levels
                current = current.parent
    raise RuntimeError("Cannot resolve the process memory cgroup mount")


def memory_budget(proc=Path("/proc")):
    values = {}
    for line in (proc / "meminfo").read_text().splitlines():
        match = re.fullmatch(r"(MemTotal|MemAvailable):\s+(\d+) kB", line)
        if match:
            values[match[1]] = int(match[2]) * 1024
    if any(values.get(name, 0) <= 0 for name in ("MemTotal", "MemAvailable")):
        raise RuntimeError("Linux total and available memory are required")
    if values["MemAvailable"] > values["MemTotal"]:
        raise RuntimeError("Invalid Linux available memory")
    levels = _memory_hierarchy(proc)
    limits = [x for x in levels if x["limitBytes"] is not None]
    capacity = min([values["MemTotal"]] + [x["limitBytes"] for x in limits])
    available = min([values["MemAvailable"]] +
                    [max(0, x["limitBytes"] - x["usageBytes"]) for x in limits])
    return {"hostTotalBytes": values["MemTotal"],
            "hostAvailableBytes": values["MemAvailable"], "cgroups": levels,
            "effectiveCapacityBytes": capacity, "effectiveAvailableBytes": available}


def run_build(command, receipt, runner_temp, *, probe=memory_budget, execute=subprocess.run):
    """Never change the existing Gradle home, project properties or signing files."""
    receipt = Path(receipt)
    if receipt.exists():
        raise FileExistsError("A hosted memory receipt already exists")
    result = {"schemaVersion": 1, "status": "PREPARATION_FAILED",
              "heapBytes": HEAP_BYTES, "metaspaceBytes": METASPACE_BYTES,
              "codeCacheBytes": CODE_CACHE_BYTES, "headroomBytes": HEADROOM_BYTES,
              "requiredAvailableBytes": REQUIRED_BYTES,
              "propertiesSha256": hashlib.sha256(PROPERTIES.encode("ascii")).hexdigest(),
              "sourceSha": os.environ.get("GITHUB_SHA")
              if re.fullmatch(r"[a-f0-9]{40}", os.environ.get("GITHUB_SHA", "")) else None}
    home = None
    exit_code = 1
    try:
        result["memory"] = probe()
        budget = result["memory"]
        if min(budget["effectiveCapacityBytes"], budget["effectiveAvailableBytes"]) < REQUIRED_BYTES:
            result["status"] = "INSUFFICIENT_MEMORY"
            raise RuntimeError("Hosted Gradle needs 4 GiB plus bounded non-heap memory and 2 GiB headroom")
        if not command:
            raise RuntimeError("A build command is required")
        # A system-property override could outrank the user-home properties.
        if "org.gradle.jvmargs" in os.environ.get("GRADLE_OPTS", ""):
            raise RuntimeError("Conflicting Gradle JVM property override")
        for name in ("JAVA_TOOL_OPTIONS", "_JAVA_OPTIONS", "JDK_JAVA_OPTIONS"):
            if os.environ.get(name):
                raise RuntimeError("Unexpected global Java options on hosted release runner")
        runner_temp = Path(runner_temp).resolve(strict=True)
        with tempfile.TemporaryDirectory(prefix="axiomara-public-gradle-", dir=runner_temp) as folder:
            home = Path(folder)
            (home / "gradle.properties").write_text(PROPERTIES, encoding="ascii")
            env = os.environ.copy()
            env["GRADLE_USER_HOME"] = str(home)
            # Keep this override inside the child process; never use GITHUB_ENV.
            completed = execute(command, env=env, check=False)
            exit_code = completed.returncode
            result.update(status="BUILD_COMMAND_EXITED", buildExitCode=exit_code)
    except Exception as error:
        # Do not serialize command arguments, signing values or the environment.
        exit_code = 1
        if result["status"] != "INSUFFICIENT_MEMORY":
            result["status"] = "WRAPPER_FAILED"
        result["errorType"] = type(error).__name__
        print("Hosted release memory preparation or build launch failed.", file=sys.stderr)
    finally:
        result["disposableGradleHomeRemoved"] = home is None or not home.exists()
        result["existingGradleHomeModified"] = False
        receipt.parent.mkdir(parents=True, exist_ok=True)
        with receipt.open("x", encoding="utf-8") as output:
            json.dump(result, output, indent=2)
            output.write("\n")
    return exit_code


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--receipt", required=True, type=Path)
    parser.add_argument("command", nargs=argparse.REMAINDER)
    args = parser.parse_args()
    if sys.platform != "linux":
        parser.error("This wrapper is for the hosted Linux release job only")
    command = args.command[1:] if args.command[:1] == ["--"] else args.command
    return run_build(command, args.receipt, os.environ["RUNNER_TEMP"])


if __name__ == "__main__":
    raise SystemExit(main())
