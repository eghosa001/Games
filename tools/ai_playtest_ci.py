#!/usr/bin/env python3
"""CI adapter for the RENEW Android AI playtester.

The Android emulator reports its physical display as portrait even when the Godot
activity is locked to landscape. The core playtester historically used that
physical size for input coordinates, which can put taps outside the rendered
2400x1080 surface. CI also shows Android's one-time immersive-mode education
overlay on a fresh emulator. This adapter removes emulator-only sources of noise
without weakening any AI findings or thresholds.
"""

from __future__ import annotations

import io
import re
import subprocess
import sys
import threading
import time

from PIL import Image

import ai_playtest as agent


def rendered_display_size() -> tuple[int, int]:
    """Return the dimensions of the surface ADB actually captures."""
    proc = subprocess.run(
        ["adb", "exec-out", "screencap", "-p"],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=True,
        timeout=30,
    )
    with Image.open(io.BytesIO(proc.stdout)) as image:
        return image.size


def robust_text_run(cmd, check=True, capture=True, timeout=120):
    """Run text-producing commands without crashing on malformed logcat bytes."""
    kwargs = {
        "text": True,
        "encoding": "utf-8",
        "errors": "replace",
        "timeout": timeout,
        "check": check,
    }
    if capture:
        kwargs.update(stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    proc = subprocess.run(cmd, **kwargs)
    return proc.stdout.strip() if capture else ""


def requested_package() -> str:
    try:
        return sys.argv[sys.argv.index("--package") + 1]
    except (ValueError, IndexError):
        return "com.eghosa.renew"


def top_package() -> str:
    """Resolve the actually resumed Android package across API-level dump formats."""
    out = robust_text_run(
        ["adb", "shell", "dumpsys", "activity", "activities"],
        check=False,
        timeout=20,
    )
    patterns = (
        r"topResumedActivity=.*?\s(?:u\d+\s+)?([\w.]+)/",
        r"mResumedActivity:.*?\s(?:u\d+\s+)?([\w.]+)/",
        r"ResumedActivity:.*?\s(?:u\d+\s+)?([\w.]+)/",
    )
    for pattern in patterns:
        match = re.search(pattern, out)
        if match:
            return match.group(1)

    out = robust_text_run(
        ["adb", "shell", "dumpsys", "activity", "top"],
        check=False,
        timeout=20,
    )
    match = re.search(r"^ACTIVITY\s+([\w.]+)/", out, re.MULTILINE)
    return match.group(1) if match else ""


def package_pid(package: str) -> str:
    return robust_text_run(
        ["adb", "shell", "pidof", package],
        check=False,
        timeout=10,
    ).strip()


def relaunch(package: str) -> None:
    robust_text_run(
        [
            "adb", "shell", "monkey", "-p", package,
            "-c", "android.intent.category.LAUNCHER", "1",
        ],
        check=False,
        timeout=30,
    )


def foreground_watchdog(package: str, stop: threading.Event) -> None:
    """Recover when exploratory Back leaves the game for Android's launcher.

    Back navigation inside RENEW is still exercised normally. Only after Android
    has actually resumed another package do we relaunch RENEW, so subsequent AI
    actions continue testing the game instead of Pixel Launcher. This does not
    suppress crashes/ANRs or change any finding threshold.
    """
    seen_running = False
    while not stop.wait(0.30):
        try:
            running = bool(package_pid(package))
            if running:
                seen_running = True
            if not seen_running or not running:
                continue
            foreground = top_package()
            if foreground and foreground != package:
                relaunch(package)
                time.sleep(0.8)
        except Exception:
            # The core playtester remains authoritative. A transient watchdog
            # query must never abort or mask its own runtime/error collection.
            time.sleep(0.3)


def main() -> None:
    # A fresh emulator otherwise puts a system-owned "Viewing full screen"
    # education dialog over the game and the vision agent tests that dialog.
    agent.wait_for_device()
    agent.adb(
        "shell", "settings", "put", "secure",
        "immersive_mode_confirmations", "confirmed",
        check=False,
    )

    # Use the currently rendered orientation for all generated input coordinates.
    # The underlying playtester still performs every visual/runtime gate unchanged.
    agent.display_size = rendered_display_size

    # Some Android/emulator logcat records contain malformed UTF-8. Preserve every
    # byte as replacement text instead of aborting the entire test harness while
    # leaving all AI detection logic and thresholds unchanged.
    agent.run = robust_text_run

    stop = threading.Event()
    watcher = threading.Thread(
        target=foreground_watchdog,
        args=(requested_package(), stop),
        daemon=True,
    )
    watcher.start()
    try:
        agent.main()
    finally:
        stop.set()
        watcher.join(timeout=2)


if __name__ == "__main__":
    main()
