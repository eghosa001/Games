#!/usr/bin/env python3
"""Reliable APK installation for the RENEW Android AI playtest CI job.

Captures the real adb install error, retries transient failures, and always writes
an infrastructure QA report when installation cannot proceed so later workflow
steps have useful evidence instead of only reporting a missing report.json.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
import time
from pathlib import Path


def run(cmd: list[str], timeout: int = 240) -> tuple[int, str]:
    try:
        p = subprocess.run(cmd, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=timeout)
        return p.returncode, p.stdout.strip()
    except subprocess.TimeoutExpired as exc:
        text = exc.stdout.decode(errors="replace") if isinstance(exc.stdout, bytes) else (exc.stdout or "")
        return 124, f"TIMEOUT after {timeout}s\n{text}"


def adb(*args: str, timeout: int = 240) -> tuple[int, str]:
    return run(["adb", *args], timeout=timeout)


def write_failure_report(out_dir: Path, package: str, apk: Path, attempts: list[dict]) -> None:
    out_dir.mkdir(parents=True, exist_ok=True)
    evidence = "\n\n".join(
        f"Attempt {a['attempt']} ({a['mode']}), exit={a['exit_code']}\n{a['output']}" for a in attempts
    )[-12000:]
    fingerprint = hashlib.sha1(("apk-install:" + evidence).encode()).hexdigest()[:12]
    finding = {
        "severity": "critical",
        "kind": "infrastructure-apk-install",
        "title": "Android emulator could not install the RENEW QA APK",
        "evidence": evidence,
        "reproduction": "Run the Android AI Playtest workflow and inspect the APK install diagnostics before the playtest step.",
    }
    report = {
        "package": package,
        "seed": 0,
        "steps": 0,
        "coverage": {
            "unique_visual_states": 0,
            "visual_transitions": 0,
            "responsive_actions": 0,
            "dead_actions": 0,
            "responsive_action_rate": 0.0,
            "learned_target_regions": 0,
        },
        "findings": [finding],
        "timeline": [],
        "fingerprint": fingerprint,
        "should_open_issue": True,
        "infrastructure_failure": True,
        "apk": str(apk),
        "install_attempts": attempts,
    }
    (out_dir / "report.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    (out_dir / "adb-install.txt").write_text(evidence + "\n", encoding="utf-8")
    md = f"""# RENEW Android AI Playtest Report

- Result: **INFRASTRUCTURE FAILURE**
- Package: `{package}`
- APK: `{apk}`
- Fingerprint: `{fingerprint}`

## [CRITICAL] Android emulator could not install the RENEW QA APK

The gameplay agent did not start because Android package installation failed after retries. This is an emulator/installation failure, not a gameplay finding.

```text
{evidence}
```

The full diagnostic is also available as `adb-install.txt`.
"""
    (out_dir / "report.md").write_text(md, encoding="utf-8")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--apk", required=True)
    ap.add_argument("--package", default="com.eghosa.renew")
    ap.add_argument("--out", default="build/ai-playtest")
    args = ap.parse_args()

    apk = Path(args.apk)
    out_dir = Path(args.out)
    if not apk.is_file() or apk.stat().st_size == 0:
        attempts = [{"attempt": 0, "mode": "preflight", "exit_code": 2, "output": f"APK missing or empty: {apk}"}]
        write_failure_report(out_dir, args.package, apk, attempts)
        print(attempts[0]["output"])
        return 2

    code, output = adb("wait-for-device", timeout=180)
    print(output)
    if code != 0:
        attempts = [{"attempt": 0, "mode": "wait-for-device", "exit_code": code, "output": output}]
        write_failure_report(out_dir, args.package, apk, attempts)
        return 2

    # Useful context when installation fails on a slow/software-emulated runner.
    for cmd in [("shell", "getprop", "ro.product.cpu.abi"), ("shell", "getprop", "ro.build.version.sdk"), ("shell", "df", "-h", "/data")]:
        _, text = adb(*cmd, timeout=60)
        print(f"$ adb {' '.join(cmd)}\n{text}")

    attempts: list[dict] = []
    modes = [
        ("no-streaming", ["install", "--no-streaming", "-r", "-t", str(apk)]),
        ("streaming", ["install", "-r", "-t", str(apk)]),
        ("clean-no-streaming", ["install", "--no-streaming", "-t", str(apk)]),
    ]

    for idx, (mode, cmd) in enumerate(modes, 1):
        if mode.startswith("clean"):
            _, uninstall_out = adb("uninstall", args.package, timeout=90)
            print(f"$ adb uninstall {args.package}\n{uninstall_out}")
        code, output = adb(*cmd, timeout=300)
        entry = {"attempt": idx, "mode": mode, "exit_code": code, "output": output}
        attempts.append(entry)
        print(f"\n=== APK install attempt {idx}: {mode} (exit {code}) ===\n{output}\n")
        if code == 0 and ("Success" in output or output == ""):
            verify_code, verify = adb("shell", "pm", "path", args.package, timeout=60)
            print(f"$ adb shell pm path {args.package}\n{verify}")
            if verify_code == 0 and "package:" in verify:
                out_dir.mkdir(parents=True, exist_ok=True)
                (out_dir / "adb-install.txt").write_text(
                    "\n\n".join(f"{a['mode']} exit={a['exit_code']}\n{a['output']}" for a in attempts) + "\n",
                    encoding="utf-8",
                )
                return 0
        adb("kill-server", timeout=30)
        time.sleep(2)
        adb("start-server", timeout=60)
        adb("wait-for-device", timeout=180)
        time.sleep(3)

    write_failure_report(out_dir, args.package, apk, attempts)
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
